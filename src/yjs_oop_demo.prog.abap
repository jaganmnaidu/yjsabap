*&---------------------------------------------------------------------*
*& Report YJS_OOP_DEMO
*&---------------------------------------------------------------------*
*& Demonstrates the core OOP concepts in ABAP using a small bank model:
*&   1. Classes, objects & constructors   7. Polymorphism
*&   2. Encapsulation                     8. Interfaces & aliases
*&   3. Static vs. instance components    9. Casting (up / down)
*&   4. Inheritance, REDEFINITION, FINAL 10. Events
*&   5. Abstraction (ABSTRACT)           11. Exception classes
*&   6. Singleton (CREATE PRIVATE)       12. Friends
*&---------------------------------------------------------------------*
REPORT yjs_oop_demo.

TYPES ty_amount TYPE p LENGTH 15 DECIMALS 2.
TYPES ty_rate   TYPE p LENGTH 5 DECIMALS 2.

*----------------------------------------------------------------------*
* Exception class: custom checked exception with its own attributes
*----------------------------------------------------------------------*
CLASS lcx_insufficient_funds DEFINITION INHERITING FROM cx_static_check.
  PUBLIC SECTION.
    DATA mv_requested TYPE ty_amount READ-ONLY.
    DATA mv_available TYPE ty_amount READ-ONLY.
    METHODS constructor
      IMPORTING iv_requested TYPE ty_amount OPTIONAL
                iv_available TYPE ty_amount OPTIONAL
                previous     TYPE REF TO cx_root OPTIONAL.
    METHODS if_message~get_text REDEFINITION.
ENDCLASS.

CLASS lcx_insufficient_funds IMPLEMENTATION.
  METHOD constructor.
    super->constructor( previous = previous ).
    mv_requested = iv_requested.
    mv_available = iv_available.
  ENDMETHOD.

  METHOD if_message~get_text.
    result = |Insufficient funds: requested { mv_requested }, available { mv_available }|.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Interface: a contract that unrelated classes can implement
*----------------------------------------------------------------------*
INTERFACE lif_printable.
  CONSTANTS c_line TYPE string VALUE `----------------------------------------`.
  METHODS print.
ENDINTERFACE.

" Forward declaration, needed for the FRIENDS addition below
CLASS lcl_auditor DEFINITION DEFERRED.

*----------------------------------------------------------------------*
* Abstract base class: cannot be instantiated, defines common behavior
*----------------------------------------------------------------------*
CLASS lcl_account DEFINITION ABSTRACT FRIENDS lcl_auditor.
  PUBLIC SECTION.
    INTERFACES lif_printable.
    ALIASES print FOR lif_printable~print.

    EVENTS low_balance EXPORTING VALUE(ev_balance) TYPE ty_amount.

    CLASS-DATA gv_bank_name TYPE string READ-ONLY.
    CLASS-METHODS class_constructor.
    CLASS-METHODS get_account_count RETURNING VALUE(rv_count) TYPE i.

    METHODS constructor
      IMPORTING iv_owner   TYPE string
                iv_balance TYPE ty_amount DEFAULT 0.
    METHODS deposit
      IMPORTING iv_amount      TYPE ty_amount
      RETURNING VALUE(ro_self) TYPE REF TO lcl_account.
    METHODS withdraw
      IMPORTING iv_amount TYPE ty_amount
      RAISING   lcx_insufficient_funds.
    METHODS get_balance RETURNING VALUE(rv_balance) TYPE ty_amount.
    " FINAL method: subclasses may not redefine it
    METHODS get_owner FINAL RETURNING VALUE(rv_owner) TYPE string.
    " ABSTRACT methods: every concrete subclass must implement them
    METHODS calculate_interest ABSTRACT RETURNING VALUE(rv_interest) TYPE ty_amount.
    METHODS get_type ABSTRACT RETURNING VALUE(rv_type) TYPE string.

  PROTECTED SECTION.
    " Visible to subclasses, hidden from the outside
    CONSTANTS c_low_balance_limit TYPE ty_amount VALUE 100.
    DATA mv_account_no TYPE i.
    METHODS set_balance IMPORTING iv_balance TYPE ty_amount.

  PRIVATE SECTION.
    " Visible only inside LCL_ACCOUNT (and its friend LCL_AUDITOR)
    CLASS-DATA gv_count TYPE i.
    DATA mv_owner   TYPE string.
    DATA mv_balance TYPE ty_amount.
ENDCLASS.

CLASS lcl_account IMPLEMENTATION.
  METHOD class_constructor.
    " Runs once, before the class is first used
    gv_bank_name = `ABAP Demo Bank`.
  ENDMETHOD.

  METHOD get_account_count.
    rv_count = gv_count.
  ENDMETHOD.

  METHOD constructor.
    gv_count      = gv_count + 1.
    mv_account_no = 1000 + gv_count.
    mv_owner      = iv_owner.
    mv_balance    = iv_balance.
  ENDMETHOD.

  METHOD deposit.
    IF iv_amount > 0.
      set_balance( mv_balance + iv_amount ).
    ENDIF.
    ro_self = me.
  ENDMETHOD.

  METHOD withdraw.
    IF iv_amount > mv_balance.
      RAISE EXCEPTION TYPE lcx_insufficient_funds
        EXPORTING iv_requested = iv_amount
                  iv_available = mv_balance.
    ENDIF.
    set_balance( mv_balance - iv_amount ).
  ENDMETHOD.

  METHOD get_balance.
    rv_balance = mv_balance.
  ENDMETHOD.

  METHOD get_owner.
    rv_owner = mv_owner.
  ENDMETHOD.

  METHOD set_balance.
    mv_balance = iv_balance.
    IF mv_balance < c_low_balance_limit.
      RAISE EVENT low_balance EXPORTING ev_balance = mv_balance.
    ENDIF.
  ENDMETHOD.

  METHOD lif_printable~print.
    " GET_TYPE( ) is abstract here - the subclass implementation runs
    WRITE: / |{ get_type( ) WIDTH = 9 } #{ mv_account_no }  { mv_owner WIDTH = 8 } balance: { mv_balance }|.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Subclass 1: inherits from LCL_ACCOUNT, extends and redefines it
*----------------------------------------------------------------------*
CLASS lcl_savings_account DEFINITION INHERITING FROM lcl_account.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_owner   TYPE string
                iv_balance TYPE ty_amount DEFAULT 0
                iv_rate    TYPE ty_rate.
    METHODS get_rate RETURNING VALUE(rv_rate) TYPE ty_rate.
    METHODS calculate_interest REDEFINITION.
    METHODS get_type REDEFINITION.
    METHODS lif_printable~print REDEFINITION.

  PRIVATE SECTION.
    DATA mv_rate TYPE ty_rate.
ENDCLASS.

CLASS lcl_savings_account IMPLEMENTATION.
  METHOD constructor.
    " The superclass constructor must be called first
    super->constructor( iv_owner = iv_owner iv_balance = iv_balance ).
    mv_rate = iv_rate.
  ENDMETHOD.

  METHOD get_rate.
    rv_rate = mv_rate.
  ENDMETHOD.

  METHOD calculate_interest.
    rv_interest = get_balance( ) * mv_rate / 100.
  ENDMETHOD.

  METHOD get_type.
    rv_type = `Savings`.
  ENDMETHOD.

  METHOD lif_printable~print.
    " Reuse the inherited implementation, then add to it
    super->lif_printable~print( ).
    WRITE: /12 |interest rate: { mv_rate }%|.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Subclass 2: FINAL - no class may inherit from it
*----------------------------------------------------------------------*
CLASS lcl_checking_account DEFINITION INHERITING FROM lcl_account FINAL.
  PUBLIC SECTION.
    METHODS constructor
      IMPORTING iv_owner           TYPE string
                iv_balance         TYPE ty_amount DEFAULT 0
                iv_overdraft_limit TYPE ty_amount.
    METHODS withdraw REDEFINITION.
    METHODS calculate_interest REDEFINITION.
    METHODS get_type REDEFINITION.

  PRIVATE SECTION.
    DATA mv_overdraft_limit TYPE ty_amount.
ENDCLASS.

CLASS lcl_checking_account IMPLEMENTATION.
  METHOD constructor.
    super->constructor( iv_owner = iv_owner iv_balance = iv_balance ).
    mv_overdraft_limit = iv_overdraft_limit.
  ENDMETHOD.

  METHOD withdraw.
    " MV_BALANCE is private in the superclass, so use the public getter
    " and the protected setter instead
    DATA lv_available TYPE ty_amount.
    lv_available = get_balance( ) + mv_overdraft_limit.
    IF iv_amount > lv_available.
      RAISE EXCEPTION TYPE lcx_insufficient_funds
        EXPORTING iv_requested = iv_amount
                  iv_available = lv_available.
    ENDIF.
    set_balance( get_balance( ) - iv_amount ).
  ENDMETHOD.

  METHOD calculate_interest.
    " No interest on checking accounts, but 10% charge when overdrawn
    IF get_balance( ) < 0.
      rv_interest = get_balance( ) * 10 / 100.
    ENDIF.
  ENDMETHOD.

  METHOD get_type.
    rv_type = `Checking`.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Event handler class
*----------------------------------------------------------------------*
CLASS lcl_notifier DEFINITION FINAL.
  PUBLIC SECTION.
    METHODS on_low_balance FOR EVENT low_balance OF lcl_account
      IMPORTING ev_balance sender.
ENDCLASS.

CLASS lcl_notifier IMPLEMENTATION.
  METHOD on_low_balance.
    WRITE: / |  >> EVENT LOW_BALANCE: { sender->get_owner( ) }'s balance is now { ev_balance }|.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Friend class: may access private components of LCL_ACCOUNT
*----------------------------------------------------------------------*
CLASS lcl_auditor DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS audit IMPORTING io_account TYPE REF TO lcl_account.
ENDCLASS.

CLASS lcl_auditor IMPLEMENTATION.
  METHOD audit.
    WRITE: / |Auditor reads PRIVATE attributes directly: owner { io_account->mv_owner }, balance { io_account->mv_balance }|.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Singleton: CREATE PRIVATE means only the class itself can instantiate
*----------------------------------------------------------------------*
CLASS lcl_bank DEFINITION FINAL CREATE PRIVATE.
  PUBLIC SECTION.
    INTERFACES lif_printable.
    TYPES tt_accounts TYPE STANDARD TABLE OF REF TO lcl_account WITH EMPTY KEY.
    CLASS-METHODS get_instance RETURNING VALUE(ro_bank) TYPE REF TO lcl_bank.
    METHODS open_account IMPORTING io_account TYPE REF TO lcl_account.
    METHODS get_accounts RETURNING VALUE(rt_accounts) TYPE tt_accounts.

  PRIVATE SECTION.
    CLASS-DATA go_instance TYPE REF TO lcl_bank.
    DATA mt_accounts TYPE tt_accounts.
ENDCLASS.

CLASS lcl_bank IMPLEMENTATION.
  METHOD get_instance.
    IF go_instance IS NOT BOUND.
      go_instance = NEW #( ).
    ENDIF.
    ro_bank = go_instance.
  ENDMETHOD.

  METHOD open_account.
    APPEND io_account TO mt_accounts.
  ENDMETHOD.

  METHOD get_accounts.
    rt_accounts = mt_accounts.
  ENDMETHOD.

  METHOD lif_printable~print.
    DATA lv_total TYPE ty_amount.
    LOOP AT mt_accounts INTO DATA(lo_account).
      lv_total = lv_total + lo_account->get_balance( ).
    ENDLOOP.
    WRITE: / |Bank: { lcl_account=>gv_bank_name }, accounts: { lines( mt_accounts ) }, total balance: { lv_total }|.
  ENDMETHOD.
ENDCLASS.

*----------------------------------------------------------------------*
* Demo driver
*----------------------------------------------------------------------*
CLASS lcl_app DEFINITION FINAL.
  PUBLIC SECTION.
    CLASS-METHODS main.

  PRIVATE SECTION.
    CLASS-METHODS print_title IMPORTING iv_title TYPE string.
ENDCLASS.

CLASS lcl_app IMPLEMENTATION.
  METHOD print_title.
    SKIP.
    WRITE: / iv_title COLOR COL_HEADING.
    ULINE.
  ENDMETHOD.

  METHOD main.
    "------------------------------------------------------------------
    print_title( `1. Classes, objects & constructors` ).
    " NEW creates an object; its CONSTRUCTOR initializes it
    DATA(lo_savings) = NEW lcl_savings_account( iv_owner   = `Alice`
                                                iv_balance = 500
                                                iv_rate    = CONV #( '2.50' ) ).
    DATA(lo_checking) = NEW lcl_checking_account( iv_owner           = `Bob`
                                                  iv_balance         = 300
                                                  iv_overdraft_limit = 200 ).
    DATA(lo_savings2) = NEW lcl_savings_account( iv_owner   = `Carol`
                                                 iv_balance = 1200
                                                 iv_rate    = CONV #( '3.00' ) ).
    lo_savings->print( ).
    lo_checking->print( ).
    lo_savings2->print( ).

    "------------------------------------------------------------------
    print_title( `2. Encapsulation (public / protected / private)` ).
    " lo_savings->mv_balance = 1000000.    -> syntax error: MV_BALANCE is private
    " lo_savings->set_balance( 1000000 ).  -> syntax error: SET_BALANCE is protected
    WRITE: / |Balance is only reachable through the public getter: { lo_savings->get_balance( ) }|.
    WRITE: / `Subclass LCL_CHECKING_ACCOUNT changes it via the protected SET_BALANCE( ).`.

    "------------------------------------------------------------------
    print_title( `3. Static vs. instance components` ).
    WRITE: / |Static attribute (set in CLASS_CONSTRUCTOR): { lcl_account=>gv_bank_name }|.
    WRITE: / |Static method - accounts created so far: { lcl_account=>get_account_count( ) }|.
    WRITE: / |Instance attribute differs per object: { lo_savings->get_owner( ) } vs. { lo_checking->get_owner( ) }|.

    "------------------------------------------------------------------
    print_title( `4. Inheritance, REDEFINITION, super->, FINAL, method chaining` ).
    " DEPOSIT is inherited from LCL_ACCOUNT and returns ME, so calls can be chained
    lo_savings->deposit( 100 )->deposit( 50 ).
    lo_savings->print( ).   " redefined: calls super->print( ) and adds the rate
    lo_checking->print( ).  " not redefined: inherited implementation
    " CLASS lcl_x DEFINITION INHERITING FROM lcl_checking_account. -> error: class is FINAL
    " METHODS get_owner REDEFINITION.                              -> error: method is FINAL

    "------------------------------------------------------------------
    print_title( `5. Abstraction (ABSTRACT class & methods)` ).
    " DATA(lo_acc) = NEW lcl_account( iv_owner = `X` ).  -> syntax error: class is abstract
    WRITE: / |GET_TYPE( ) is abstract in LCL_ACCOUNT; subclasses implement it: { lo_savings->get_type( ) }, { lo_checking->get_type( ) }|.

    "------------------------------------------------------------------
    print_title( `6. Singleton (CREATE PRIVATE)` ).
    " DATA(lo_other_bank) = NEW lcl_bank( ).  -> syntax error: only LCL_BANK may instantiate itself
    DATA(lo_bank) = lcl_bank=>get_instance( ).
    lo_bank->open_account( lo_savings ).    " implicit up-cast to REF TO lcl_account
    lo_bank->open_account( lo_checking ).
    lo_bank->open_account( lo_savings2 ).
    IF lo_bank = lcl_bank=>get_instance( ).
      WRITE: / `GET_INSTANCE( ) always returns the same object.`.
    ENDIF.

    "------------------------------------------------------------------
    print_title( `7. Polymorphism (dynamic dispatch through a superclass reference)` ).
    DATA(lt_accounts) = lo_bank->get_accounts( ).
    LOOP AT lt_accounts INTO DATA(lo_account).
      " Same call - the implementation is chosen by the object's runtime type
      WRITE: / |{ lo_account->get_owner( ) WIDTH = 8 } ({ lo_account->get_type( ) WIDTH = 8 }) interest: { lo_account->calculate_interest( ) }|.
    ENDLOOP.

    "------------------------------------------------------------------
    print_title( `8. Interfaces & aliases` ).
    " LCL_BANK and LCL_ACCOUNT are unrelated, but both implement LIF_PRINTABLE
    DATA lt_printables TYPE STANDARD TABLE OF REF TO lif_printable WITH EMPTY KEY.
    lt_printables = VALUE #( ( lo_bank ) ( lo_savings ) ( lo_checking ) ).
    LOOP AT lt_printables INTO DATA(lo_printable).
      lo_printable->print( ).
    ENDLOOP.
    WRITE: / lif_printable=>c_line.
    WRITE: / `LO_SAVINGS->PRINT( ) works through the alias for LIF_PRINTABLE~PRINT.`.

    "------------------------------------------------------------------
    print_title( `9. Casting (up-cast, down-cast, IS INSTANCE OF)` ).
    DATA lo_base TYPE REF TO lcl_account.
    lo_base = lo_savings2.  " up-cast: always safe, implicit
    IF lo_base IS INSTANCE OF lcl_savings_account.
      " down-cast: needed to call a subclass-only method
      DATA(lo_sav) = CAST lcl_savings_account( lo_base ).
      WRITE: / |Down-cast OK, subclass-only GET_RATE( ): { lo_sav->get_rate( ) }%|.
    ENDIF.
    TRY.
        DATA(lo_chk) = CAST lcl_checking_account( lo_base ).
        lo_chk->print( ).
      CATCH cx_sy_move_cast_error INTO DATA(lx_cast).
        WRITE: / |Invalid down-cast caught: { lx_cast->get_text( ) }|.
    ENDTRY.

    "------------------------------------------------------------------
    print_title( `10. Events (RAISE EVENT / SET HANDLER)` ).
    DATA(lo_notifier) = NEW lcl_notifier( ).
    SET HANDLER lo_notifier->on_low_balance FOR ALL INSTANCES.
    TRY.
        WRITE: / `Bob withdraws 250 ...`.
        lo_checking->withdraw( 250 ).  " balance drops below 100 -> event fires
      CATCH lcx_insufficient_funds INTO DATA(lx_funds).
        WRITE: / |{ lx_funds->get_text( ) }|.
    ENDTRY.

    "------------------------------------------------------------------
    print_title( `11. Exception classes (RAISE EXCEPTION / TRY ... CATCH)` ).
    TRY.
        WRITE: / `Alice withdraws 10000 ...`.
        lo_savings->withdraw( 10000 ).
      CATCH lcx_insufficient_funds INTO lx_funds.
        WRITE: / |{ lx_funds->get_text( ) }|.
        WRITE: / |Exception attributes: requested { lx_funds->mv_requested }, available { lx_funds->mv_available }|.
    ENDTRY.
    TRY.
        " Redefined WITHDRAW in the checking account allows an overdraft
        WRITE: / `Bob withdraws 200 (within overdraft) ...`.
        lo_checking->withdraw( 200 ).
        WRITE: / |Bob's balance: { lo_checking->get_balance( ) }, interest: { lo_checking->calculate_interest( ) }|.
        WRITE: / `Bob withdraws 500 ...`.
        lo_checking->withdraw( 500 ).
      CATCH lcx_insufficient_funds INTO lx_funds.
        WRITE: / |{ lx_funds->get_text( ) }|.
    ENDTRY.

    "------------------------------------------------------------------
    print_title( `12. Friends (FRIENDS addition)` ).
    lcl_auditor=>audit( lo_savings ).
  ENDMETHOD.
ENDCLASS.

START-OF-SELECTION.
  lcl_app=>main( ).
