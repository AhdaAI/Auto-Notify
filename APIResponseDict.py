from typing import List, Optional
from pydantic import BaseModel


class DiscountSetting(BaseModel):
    discountType: str | None = None
    discountPercentage: int | None = None


class PromotionalOffer(BaseModel):
    startDate: str | None = None
    endDate: str | None = None
    discountSetting: dict | None = None
    discountPercentage: int | None = None


class PromotionalOffersWrapper(BaseModel):
    promotionalOffers: List[PromotionalOffer]


class Promotions(BaseModel):
    promotionalOffers: List[PromotionalOffersWrapper] = []
    upcomingPromotionalOffers: List[PromotionalOffersWrapper] = []


class PriceFmt(BaseModel):
    originalPrice: str
    discountPrice: str
    intermediatePrice: str


class CurrencyInfo(BaseModel):
    decimals: int


class TotalPrice(BaseModel):
    discountPrice: int
    originalPrice: int
    voucherDiscount: int
    discount: int
    currencyCode: str
    currencyInfo: CurrencyInfo
    fmtPrice: PriceFmt


class AppliedRule(BaseModel):
    id: str
    endDate: Optional[str]
    discountSetting: Optional[DiscountSetting]


class LineOffer(BaseModel):
    appliedRules: List[AppliedRule]


class Price(BaseModel):
    totalPrice: TotalPrice
    lineOffers: List[LineOffer]


class Mapping(BaseModel):
    pageSlug: str
    pageType: str


class CatalogNs(BaseModel):
    mappings: Optional[List[Mapping]] = None


class OfferMapping(BaseModel):
    pageSlug: str
    pageType: str


class Tag(BaseModel):
    id: str


class Category(BaseModel):
    path: str


class CustomAttribute(BaseModel):
    key: str
    value: str


class Item(BaseModel):
    id: str
    namespace: str


class Seller(BaseModel):
    id: str
    name: str


class KeyImage(BaseModel):
    type: str
    url: str


class Element(BaseModel):
    title: str
    id: str
    namespace: str
    description: str
    effectiveDate: str
    offerType: str
    expiryDate: Optional[str]
    viewableDate: Optional[str]
    status: str
    isCodeRedemptionOnly: bool
    keyImages: List[KeyImage]
    seller: Seller
    productSlug: Optional[str]
    urlSlug: Optional[str]
    url: Optional[str]
    items: List[Item]
    customAttributes: List[CustomAttribute]
    categories: List[Category]
    tags: List[Tag]
    catalogNs: Optional[CatalogNs] = None
    offerMappings: Optional[List[OfferMapping]] = None
    price: Price
    promotions: Optional[Promotions] = None


class SearchStore(BaseModel):
    elements: List[Element]


class Catalog(BaseModel):
    searchStore: SearchStore


class Data(BaseModel):
    Catalog: Catalog


class APIResponse(BaseModel):
    data: Data
