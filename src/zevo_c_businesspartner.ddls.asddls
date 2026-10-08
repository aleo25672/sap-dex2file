@EndUserText.label: 'Business Partner (C2P)'
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MIXED }
define view entity ZEVO_C_BusinessPartner
  as select from I_BusinessPartner
  association [0..*] to ZEVO_C_BPSupplier as _BPSupplier
    on $projection.BusinessPartner = _BPSupplier.BusinessPartner
{
  *,
  _BPSupplier
}
