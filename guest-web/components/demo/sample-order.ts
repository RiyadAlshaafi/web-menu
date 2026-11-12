export const sampleTable = 7;

export const sampleCafe = { en: "Medina Café", ar: "مقهى المدينة" };

export const sampleCategories = [
  { id: "coffee", en: "Coffee", ar: "قهوة" },
  { id: "pizza", en: "Pizza", ar: "بيتزا" },
  { id: "desserts", en: "Desserts", ar: "حلويات" },
] as const;

export const sampleTicket = { "margherita-pizza": 1, cappuccino: 2 };

export const sampleMenu = [
  {
    id: "espresso",
    category: "coffee",
    nameEn: "Espresso",
    nameAr: "إسبريسو",
    description: {
      en: "A single shot of espresso with a rich crema.",
      ar: "جرعة إسبريسو واحدة بطبقة كريما غنية.",
    },
    price: 7,
    photoCredit: { author: "Berthold Werner", file: "Espresso_BW_1.jpg", license: "Public domain", licensePath: null },
  },
  {
    id: "cappuccino",
    category: "coffee",
    nameEn: "Cappuccino",
    nameAr: "كابتشينو",
    description: {
      en: "Espresso with steamed milk and silky foam.",
      ar: "إسبريسو مع حليب مبخّر ورغوة ناعمة.",
    },
    price: 10,
    photoCredit: { author: "Blanka Novotná", file: "Cappuchino_latte_art.jpg", license: "Public domain", licensePath: null },
  },
  {
    id: "margherita-pizza",
    category: "pizza",
    nameEn: "Margherita pizza",
    nameAr: "بيتزا مارغريتا",
    description: {
      en: "Tomato sauce, fresh mozzarella and basil.",
      ar: "صلصة طماطم وموزاريلا طازجة وريحان.",
    },
    price: 28,
    photoCredit: {
      author: "City Foodsters",
      file: "Our_Original_Margherita_Pizza_-_Large_8_slices._Made_with_fresh_mozzarella_San_Marzano_tomato_sauce_and_topped_with_pecorino_Romano_and_fresh_basil_-_9345776001.jpg",
      license: "CC BY 2.0",
      licensePath: "by/2.0",
    },
  },
  {
    id: "cheesecake",
    category: "desserts",
    nameEn: "Blueberry cheesecake",
    nameAr: "تشيز كيك بالتوت الأزرق",
    description: {
      en: "Creamy cheesecake with a biscuit crust and blueberry topping.",
      ar: "تشيز كيك كريمي بقاعدة بسكويت وطبقة توت أزرق.",
    },
    price: 14,
    photoCredit: { author: "EvanProdromou", file: "New_York_cheesecake_2.jpg", license: "CC BY-SA 4.0", licensePath: "by-sa/4.0" },
  },
] as const;

export const demoCopy = {
  en: {
    label: "Demo · Sample data",
    reset: "Reset demo",
    browse: "Choose dishes",
    review: "Review order",
    sent: "Order sent",
    browseHint: "You’ve opened the menu at table 7. Add a dish to start your order.",
    reviewHint: "Check your items before sending your order.",
    sentHint: "In a live café, the kitchen would now receive this order.",
    progress: "Order progress",
    empty: "Your order is empty",
    done: "Start again",
    categories: "Menu categories",
    credits: "Photo credits",
    photoChanges: "Cropped and resized",
  },
  ar: {
    label: "عرض تجريبي · بيانات نموذجية",
    reset: "إعادة ضبط العرض",
    browse: "اختيار الأطباق",
    review: "مراجعة الطلب",
    sent: "تم إرسال الطلب",
    browseHint: "فتحت قائمة الطاولة 7. أضف طبقًا لبدء طلبك.",
    reviewHint: "راجع الأصناف قبل إرسال طلبك.",
    sentHint: "في المقهى الفعلي، سيستلم المطبخ هذا الطلب الآن.",
    progress: "مراحل الطلب",
    empty: "طلبك فارغ",
    done: "ابدأ من جديد",
    categories: "أقسام القائمة",
    credits: "مصادر الصور",
    photoChanges: "قُصّت الصور وغُيّر حجمها",
  },
} as const;
