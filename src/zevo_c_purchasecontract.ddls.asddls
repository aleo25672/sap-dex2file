@AbapCatalog.sqlViewName: 'ZEVOCPURCONTR'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Contract Header (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchaseContract
  as select from C_PurchaseContractDEX
  association [0..*] to ZEVO_C_PurchContractItem as _Item
    on $projection.PurchaseContract = _Item.PurchaseContract
  association [0..1] to ZEVO_C_BusinessPartner as _Supplier
    on $projection.Supplier = _Supplier.BusinessPartner
  association [0..*] to ZEVO_C_BPSupplier as _BPSupplier
    on $projection.Supplier = _BPSupplier.Supplier
{
  *,
  _Item,
  _Supplier,
  _BPSupplier
}
