@EndUserText.label: 'Supplier Invoice Header (C2P)'
@AccessControl.authorizationCheck: #CHECK
@Metadata.ignorePropagatedAnnotations: false
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MIXED }
define view entity ZEVO_C_SupplierInvoice
  as select from C_SupplierInvoiceDEX
  association [0..*] to ZEVO_C_SupplierInvItem as _Item
    on $projection.SupplierInvoice = _Item.SupplierInvoice
       and $projection.FiscalYear = _Item.FiscalYear
  association [0..1] to ZEVO_C_BusinessPartner as _InvoicingParty
    on $projection.InvoicingParty = _InvoicingParty.BusinessPartner
{
  *,
  _Item,
  _InvoicingParty
}
