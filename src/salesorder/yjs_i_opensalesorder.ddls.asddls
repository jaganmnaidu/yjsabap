@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Open Sales Orders (EPM)'
@Metadata.allowExtensions: true
@ObjectModel.semanticKey: [ 'SalesOrder' ]
@Search.searchable: true

/* Open = lifecycle status New (N) or In Progress (P);
   Closed (C) and Cancelled (X) orders are excluded */
define view entity YJS_I_OpenSalesOrder
  as select from    snwd_so  as SalesOrder
    inner join      snwd_bpa as Customer on Customer.node_key = SalesOrder.buyer_guid
    left outer join snwd_ad  as Address  on Address.node_key = Customer.address_guid

  association [0..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _LifecycleStatusText
    on  _LifecycleStatusText.value_low = $projection.LifecycleStatus
    and _LifecycleStatusText.language  = $session.system_language
  association [0..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _BillingStatusText
    on  _BillingStatusText.value_low = $projection.BillingStatus
    and _BillingStatusText.language  = $session.system_language
  association [0..1] to DDCDS_CUSTOMER_DOMAIN_VALUE_T as _DeliveryStatusText
    on  _DeliveryStatusText.value_low = $projection.DeliveryStatus
    and _DeliveryStatusText.language  = $session.system_language
{
  key SalesOrder.node_key                                      as SalesOrderUUID,

      @Search.defaultSearchElement: true
      SalesOrder.so_id                                         as SalesOrder,

      SalesOrder.created_at                                    as CreatedAt,

      @Search.defaultSearchElement: true
      @ObjectModel.text.element: [ 'CustomerName' ]
      @Consumption.valueHelpDefinition: [ { entity: { name: 'YJS_I_SOCustomerVH', element: 'CustomerID' } } ]
      Customer.bp_id                                           as CustomerID,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text: true
      Customer.company_name                                    as CustomerName,

      Address.city                                             as City,
      Address.country                                          as Country,

      @Semantics.amount.currencyCode: 'CurrencyCode'
      SalesOrder.gross_amount                                  as GrossAmount,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      SalesOrder.net_amount                                    as NetAmount,
      @Semantics.amount.currencyCode: 'CurrencyCode'
      SalesOrder.tax_amount                                    as TaxAmount,
      SalesOrder.currency_code                                 as CurrencyCode,

      @ObjectModel.text.element: [ 'LifecycleStatusText' ]
      SalesOrder.lifecycle_status                              as LifecycleStatus,
      @Semantics.text: true
      _LifecycleStatusText( p_domain_name: 'D_SO_LC' ).text    as LifecycleStatusText,

      @ObjectModel.text.element: [ 'BillingStatusText' ]
      SalesOrder.billing_status                                as BillingStatus,
      @Semantics.text: true
      _BillingStatusText( p_domain_name: 'D_SO_CF' ).text      as BillingStatusText,

      @ObjectModel.text.element: [ 'DeliveryStatusText' ]
      SalesOrder.delivery_status                               as DeliveryStatus,
      @Semantics.text: true
      _DeliveryStatusText( p_domain_name: 'D_SO_OR' ).text     as DeliveryStatusText,

      /* Status colour in the list: New = orange, In Progress = green */
      case SalesOrder.lifecycle_status
        when 'N' then 2
        when 'P' then 3
        else 0
      end                                                      as StatusCriticality
}
where SalesOrder.lifecycle_status <> 'C'
  and SalesOrder.lifecycle_status <> 'X'
