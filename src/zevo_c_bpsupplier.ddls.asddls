@AbapCatalog.sqlViewName: 'ZEVOCBPSUPPL'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner Supplier Role (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_C_BPSupplier
  as select from I_BusinessPartnerSupplierDEX
  association [1..1] to ZEVO_C_BusinessPartner as _BusinessPartner
    on $projection.BusinessPartner = _BusinessPartner.BusinessPartner
{
  *,
  _BusinessPartner
}
