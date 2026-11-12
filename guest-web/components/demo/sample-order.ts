export const sampleTable = 7;

export const sampleCafe = { en: "Medina Café", ar: "مقهى المدينة" };

export const sampleMenu = [
  {
    id: "shakshuka",
    nameEn: "Shakshuka",
    nameAr: "شكشوكة",
    description: {
      en: "Eggs simmered with tomato and peppers, served with warm bread.",
      ar: "بيض مطهو مع الطماطم والفلفل، يُقدّم مع خبز ساخن.",
    },
    price: 18,
  },
  {
    id: "chicken-ciabatta",
    nameEn: "Grilled chicken ciabatta",
    nameAr: "تشاباتا بالدجاج المشوي",
    description: {
      en: "Grilled chicken, rocket and lemon aioli on toasted ciabatta.",
      ar: "دجاج مشوي وجرجير وأيولي بالليمون في خبز تشاباتا محمّص.",
    },
    price: 24,
  },
  {
    id: "mint-lemonade",
    nameEn: "Mint lemonade",
    nameAr: "ليمون بالنعناع",
    description: {
      en: "Fresh lemon blended with mint and crushed ice.",
      ar: "ليمون طازج ممزوج بالنعناع والثلج المجروش.",
    },
    price: 9.5,
  },
  {
    id: "date-cake",
    nameEn: "Warm date cake",
    nameAr: "كيكة التمر الدافئة",
    description: {
      en: "Date sponge with tahini caramel and toasted sesame.",
      ar: "كيكة تمر مع كراميل الطحينة وسمسم محمّص.",
    },
    price: 12,
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
    reviewHint: "Check your items and add a note for the kitchen if you like.",
    sentHint: "In a live café, the kitchen would now receive this order.",
    note: "Kitchen note (optional)",
    notePlaceholder: "For example, sauce on the side",
    progress: "Order progress",
    empty: "Your order is empty",
    done: "Start again",
  },
  ar: {
    label: "عرض تجريبي · بيانات نموذجية",
    reset: "إعادة ضبط العرض",
    browse: "اختيار الأطباق",
    review: "مراجعة الطلب",
    sent: "تم إرسال الطلب",
    browseHint: "فتحت قائمة الطاولة 7. أضف طبقًا لبدء طلبك.",
    reviewHint: "راجع الأصناف وأضف ملاحظة للمطبخ إن أردت.",
    sentHint: "في المقهى الفعلي، سيستلم المطبخ هذا الطلب الآن.",
    note: "ملاحظة للمطبخ (اختياري)",
    notePlaceholder: "مثلًا، الصلصة على الجانب",
    progress: "مراحل الطلب",
    empty: "طلبك فارغ",
    done: "ابدأ من جديد",
  },
} as const;
