@AbapCatalog.sqlViewName: 'ZEVOOGOODSMVT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Goods Movement Document (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_GoodsMovementDoc
  as select from I_GoodsMovementDocumentDEX
  association [0..1] to ZEVO_O_BusinessPartner as _Customer
    on $projection.Customer = _Customer.BusinessPartner
{
  key MaterialDocumentYear,
  key MaterialDocument,
  key MaterialDocumentItem,
      Plant,
      StorageLocation,
      Material,
      Batch,
      CompanyCode,
      @Semantics.businessDate.at: true
      PostingDate,
      CreationDate,
      DocumentDate,
      GoodsMovementType,
      InventoryTransactionType,
      SalesOrder,
      SalesOrderItem,
      DeliveryDocument,
      DeliveryDocumentItem,
      PurchaseOrder,
      PurchaseOrderItem,
      Supplier,
      Customer,
      QuantityInBaseUnit,
      MaterialBaseUnit,
      GoodsMovementIsCancelled,
      IsReversalMovementType,
      _Customer
}
