// Shapes the guest API returns. Shared by the route handlers and the pages.
export type Cafe = {
  id: string;
  name: string;
  locale: string;
  logoUrl: string;
  headerColor: string;
  buttonColor: string;
  backgroundColor: string;
  serviceChargeRate: number;
};

export type Category = { id: string; nameEn: string; nameAr: string };

// One ingredient or extra topping of a dish. Only an option that is off by default and turned on
// is charged; removing a default ingredient is free.
export type DishOption = {
  id: string;
  kind: "ingredient" | "topping";
  nameEn: string;
  nameAr: string;
  price: number;
  defaultOn: boolean;
};

export type MenuItem = {
  id: string;
  categoryId: string;
  nameEn: string;
  nameAr: string;
  description: string;
  price: number;
  salePrice: number;
  imageUrl: string;
  available: boolean;
  featured: boolean;
  options: DishOption[];
};

export type PaymentType = { id: string; nameEn: string; nameAr: string };

export type Menu = {
  cafe: Cafe;
  table: { number: string };
  categories: Category[];
  items: MenuItem[];
  paymentTypes: PaymentType[];
};

export type GuestStatus = { orderingOpen: boolean; location: { enabled: boolean; radiusM: number } };

export type LocationVerdict = {
  enabled: boolean;
  radiusM: number;
  status: "allowed" | "too_far" | "location_required" | null;
};

export type OrderSent = { orderId: string; round: number };

export type TabLine = {
  id: string;
  menuItemId: string | null;
  name: string;
  qty: number;
  unitPrice: number;
  listUnitPrice: number | null;
  round: number;
  choices: LineChoice[];
};

// A choice on a sent line that differs from the dish defaults; price is what was charged.
export type LineChoice = { id: string; nameEn: string; nameAr: string; on: boolean; price: number };

export type OrderStatus = "received" | "preparing" | "ready" | "served" | "paid" | string;

export type TabOrder = {
  id: string;
  status: OrderStatus;
  createdAt: string;
  orderNumber: number | null;
  awaitingConfirmation: boolean;
  refusalNotice: string;
  paymentTypeId: string | null;
  lines: TabLine[];
};

export type Tab = { table: { number: string; status: string }; order: TabOrder | null };

export type Done = { done: true };

// "owner" may order at this table; "viewer" can only look at the menu because another phone holds
// the table; "none" means nobody holds it and this phone is not (yet) at the cafe to take it.
export type TableClaim = { role: "owner" | "viewer" | "none" };
