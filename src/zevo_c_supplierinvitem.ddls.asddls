@AbapCatalog.sqlViewName: 'ZEVOCSUPPITEM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Supplier Invoice Item (C2P)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_C_SupplierInvItem
  as select from C_SupplierInvoiceItemDEX
  association [0..*] to ZEVO_C_GoodsMovementDoc as _GoodsMovement
    on $projection.PrmthbReferenceDocument = _GoodsMovement.MaterialDocument and $projection.PrmthbReferenceDocumentFsclyr = _GoodsMovement.MaterialDocumentYear
{
  key SupplierInvoice,
  key FiscalYear,
  key SupplierInvoiceItem,
      QtyInPurchaseOrderPriceUnit,
      PurchaseOrderPriceUnit,
      PurchaseOrderQuantityUnit,
      PurchaseOrder,
      PurchaseOrderItem,
      PrmthbReferenceDocument,
      PrmthbReferenceDocumentFsclyr,
      PrmthbReferenceDocumentItem,
      PurchaseOrderItemMaterial,
      QuantityInPurchaseOrderUnit,
      SuplrInvcItmHasQualityVariance,
      SuplrInvcItemHasOrdPrcQtyVarc,
      SuplrInvcItemHasQtyVariance,
      SuplrInvcItemHasPriceVariance,
      SuplrInvcItemHasOtherVariance,
      SuplrInvcItemHasAmountOutsdTol,
      SuplrInvcItemHasDateVariance,
      IsSubsequentDebitCredit,
      Plant,
      DocumentCurrency,
      SupplierInvoiceItemAmount,
      SuplrInvcAutomReducedAmount,
      UnplannedDeliveryCost,
      DocumentHeaderText,
      DocumentDate,
      @Semantics.businessDate.at: true
      PostingDate,
      CompanyCode,
      SupplierInvoiceOrigin,
      InvoicingParty,
      UnplannedDeliveryCostTaxCode,
      ReverseDocument,
      ReverseDocumentFiscalYear,
      SupplierInvoiceIDByInvcgParty,
      IsInvoice,
      SupplierInvoiceStatus,
      _GoodsMovement
}
