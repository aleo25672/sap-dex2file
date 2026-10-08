@AbapCatalog.sqlViewName: 'ZEVOCPURCHORD'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Order Header (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchaseOrder
  as select from C_PurchaseOrderDEX
  association [0..*] to ZEVO_C_PurchaseOrderItem as _Item
    on $projection.PurchaseOrder = _Item.PurchaseOrder
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
