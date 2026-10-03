@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Customer Value Help (EPM)'
@ObjectModel.dataCategory: #VALUE_HELP
@Search.searchable: true

define view entity YJS_I_SOCustomerVH
  as select from    snwd_bpa as Customer
    left outer join snwd_ad  as Address on Address.node_key = Customer.address_guid
{
      @Search.defaultSearchElement: true
      @ObjectModel.text.element: [ 'CustomerName' ]
  key Customer.bp_id        as CustomerID,

      @Search.defaultSearchElement: true
      @Search.fuzzinessThreshold: 0.8
      @Semantics.text: true
      Customer.company_name as CustomerName,

      Address.city          as City,
      Address.country       as Country
}
