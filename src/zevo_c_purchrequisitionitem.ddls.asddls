@AbapCatalog.sqlViewName: 'ZEVOCPRITEM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Requisition Item (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchRequisitionItem
  as select from C_PurchaseRequisitionItemDEX
  association [0..*] to ZEVO_C_PurchaseOrderItem as _PurchaseOrderItem
    on $projection.PurchaseRequisition = _PurchaseOrderItem.PurchaseRequisition
       and $projection.PurchaseRequisitionItem = _PurchaseOrderItem.PurchaseRequisitionItem
  association [0..*] to ZEVO_C_PurchContractItem as _PurchaseContractItem
    on $projection.PurchaseContract = _PurchaseContractItem.PurchaseContract
       and $projection.PurchaseContractItem = _PurchaseContractItem.PurchaseContractItem
  association [0..1] to ZEVO_C_BusinessPartner as _Supplier
    on $projection.Supplier = _Supplier.BusinessPartner
{
  *,
  _PurchaseOrderItem,
  _PurchaseContractItem,
  _Supplier
}
