@AbapCatalog.sqlViewName: 'ZEVOMPRODUCT'
@AbapCatalog.compiler.compareFilter: true
@AccessControl.authorizationCheck: #CHECK
@EndUserText.label: 'Product (Master Data)'
@ObjectModel.usageType: { serviceQuality: #D, sizeCategory: #XL, dataClass: #MASTER }
define view ZEVO_M_Product
  as select from I_Product
{
  key Product,
      ProductType as ProductTypeCode,
      ProductGroup,
      BaseUnit,
      ProductOldID,
      GrossWeight,
      WeightUnit,
      NetWeight,
      ProductHierarchy,
      Division,
      IsMarkedForDeletion,
      CrossPlantStatus,
      CrossPlantStatusValidityDate,
      IndustrySector,
      ItemCategoryGroup,
      AuthorizationGroup,
      CreatedByUser,
      CreationDate,
      LastChangedByUser,
      @Semantics.systemDate.lastChangedAt: true
      LastChangeDate
}
