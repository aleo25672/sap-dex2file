@AbapCatalog.sqlViewName: 'ZEVOOOUTBDITM'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Outbound Delivery Item (C2C)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #TRANSACTIONAL }
define view ZEVO_O_OutboundDelivItem
  as select from I_DeliveryDocumentItem
{
  key DeliveryDocument     as OutboundDelivery,
  key DeliveryDocumentItem as OutboundDeliveryItem,
      SDDocumentCategory,
      CreationDate,
      CreationTime,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate,
      Material,
      Product,
      Plant,
      ActualDeliveryQuantity,
      DeliveryQuantityUnit,
      ActualDeliveredQtyInBaseUnit,
      BaseUnit,
      // SO link — not on C_OutboundDeliveryItemDEX; use I_* for FK $expand
      ReferenceSDDocument,
      ReferenceSDDocumentItem,
      ReferenceSDDocumentCategory
}
where SDDocumentCategory = 'J'
