@AbapCatalog.sqlViewName: 'ZEVOCBPARTNER'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Business Partner (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_C_BusinessPartner
  as select from I_BusinessPartner
  association [0..*] to ZEVO_C_BPSupplier as _BPSupplier
    on $projection.BusinessPartner = _BPSupplier.BusinessPartner
{
  *,
  _BPSupplier
}
