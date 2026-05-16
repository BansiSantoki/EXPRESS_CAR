# 🚀 Razorpay Quick Start - Copy & Paste Commands

## Project: Express Car (expresscar-75596)

---

## 1️⃣ DEPLOY BACKEND (Do This First)

```bash
cd functions
npm install
firebase deploy --only functions
```

**Wait for deployment to complete successfully ✓**

---

## 2️⃣ RUN APP WITH PAYMENT (After Deployment)

### For Windows:

```bash
flutter run -d windows --dart-define=RAZORPAY_KEY_ID=rzp_test_SiOMYi5nmRkGyl --dart-define=PAYMENT_CREATE_ORDER_URL=https://us-central1-expresscar-75596.cloudfunctions.net/createRazorpayOrder --dart-define=PAYMENT_VERIFY_URL=https://us-central1-expresscar-75596.cloudfunctions.net/verifyRazorpayPayment --dart-define=PAYMENT_FAILURE_URL=https://us-central1-expresscar-75596.cloudfunctions.net/markPaymentFailed
```

### For Android:

```bash
flutter build apk --release --dart-define=RAZORPAY_KEY_ID=rzp_test_SiOMYi5nmRkGyl --dart-define=PAYMENT_CREATE_ORDER_URL=https://us-central1-expresscar-75596.cloudfunctions.net/createRazorpayOrder --dart-define=PAYMENT_VERIFY_URL=https://us-central1-expresscar-75596.cloudfunctions.net/verifyRazorpayPayment --dart-define=PAYMENT_FAILURE_URL=https://us-central1-expresscar-75596.cloudfunctions.net/markPaymentFailed
```

### For iOS:

```bash
flutter build ipa --release --dart-define=RAZORPAY_KEY_ID=rzp_test_SiOMYi5nmRkGyl --dart-define=PAYMENT_CREATE_ORDER_URL=https://us-central1-expresscar-75596.cloudfunctions.net/createRazorpayOrder --dart-define=PAYMENT_VERIFY_URL=https://us-central1-expresscar-75596.cloudfunctions.net/verifyRazorpayPayment --dart-define=PAYMENT_FAILURE_URL=https://us-central1-expresscar-75596.cloudfunctions.net/markPaymentFailed
```

---

## 3️⃣ TEST PAYMENT

**Test Card (Success):**

- Number: `4111 1111 1111 1111`
- Expiry: `12/25` (or any future date)
- CVV: `123`

**Test Card (Failure):**

- Number: `4222 2222 2222 2222`
- Expiry: `12/25` (or any future date)
- CVV: `123`

### In App:

1. Sign In
2. Select Car → Create Booking
3. Tap "Pay Online"
4. Enter test card details
5. Complete payment
6. Check if booking shows "paid" status

---

## ✅ Verification Checklist

- [ ] Functions deployed successfully
- [ ] Flutter app runs with dart-defines
- [ ] Test payment goes through Razorpay checkout
- [ ] Booking document updated with `payment_status: "paid"`
- [ ] Can add rating & review after payment
- [ ] Payment shows in Razorpay dashboard

---

## 🆘 Quick Troubleshooting

### App shows "Missing payment URLs" error?

→ You're missing the `--dart-define` flags. Copy the command from Step 2️⃣ above exactly.

### Payment doesn't go through?

→ Check if you're signed in first. User must be authenticated.

### Payment shows in Razorpay but not in Firebase?

→ Check Cloud Functions logs: Firebase Console → Functions → Logs

### Functions won't deploy?

→ Make sure `.env` file exists in `functions/` with Razorpay keys.

---

## 📊 Monitor Everything

**Firebase Console:**

- Check functions: https://console.firebase.google.com/project/expresscar-75596/functions
- Check bookings: https://console.firebase.google.com/project/expresscar-75596/firestore/

**Razorpay Dashboard:**

- View payments: https://dashboard.razorpay.com

---

**Status:** ✅ Ready to Deploy
**Current Keys:** TEST mode (rzp*test*\*)
**Production:** Replace keys before going live
