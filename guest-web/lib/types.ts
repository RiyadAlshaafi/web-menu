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
};

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
