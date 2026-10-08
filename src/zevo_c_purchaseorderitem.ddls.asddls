@AbapCatalog.sqlViewName: 'ZEVOCPUROITEM'
@AbapCatalog.compiler.compareFilter: true
@AbapCatalog.preserveKey: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Purchase Order Item (C2P)'
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_PurchaseOrderItem
  as select from C_PurchaseOrderItemDEX
  association [1..1] to ZEVO_C_PurchaseOrder as _Header
    on $projection.PurchaseOrder = _Header.PurchaseOrder
  association [0..*] to ZEVO_C_PurchaseOrderHist as _History
    on $projection.PurchaseOrder = _History.PurchaseOrder
       and $projection.PurchaseOrderItem = _History.PurchaseOrderItem
  association [0..*] to ZEVO_C_PurOrdAcctAssgmt as _AccountAssignment
    on $projection.PurchaseOrder = _AccountAssignment.PurchaseOrder
       and $projection.PurchaseOrderItem = _AccountAssignment.PurchaseOrderItem
  association [0..1] to ZEVO_C_PurchRequisitionItem as _PurchaseRequisitionItem
    on $projection.PurchaseRequisition = _PurchaseRequisitionItem.PurchaseRequisition
       and $projection.PurchaseRequisitionItem = _PurchaseRequisitionItem.PurchaseRequisitionItem
  association [0..1] to ZEVO_C_PurchContractItem as _PurchaseContractItem
    on $projection.PurchaseContract = _PurchaseContractItem.PurchaseContract
       and $projection.PurchaseContractItem = _PurchaseContractItem.PurchaseContractItem
{
  *,
  _Header,
  _History,
  _AccountAssignment,
  _PurchaseRequisitionItem,
  _PurchaseContractItem
}
