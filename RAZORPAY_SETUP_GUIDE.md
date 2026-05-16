# Razorpay Payment Integration - Complete Setup Guide

## Project: Express Car Rental App

**Firebase Project ID:** expresscar-75596

---

## ✅ Step 1: Razorpay Keys (Already Configured)

Your Razorpay keys are stored in `functions/.env`:

```env
RAZORPAY_KEY_ID=rzp_test_SiOMYi5nmRkGyl
RAZORPAY_KEY_SECRET=VOoLaWdK2e7yuxgpWQQPBiQc
```

**Note:** These are TEST keys. For production, replace with your live Razorpay keys from https://dashboard.razorpay.com

---

## 📋 Step 2: Deploy Backend Functions

The payment backend is ready in `functions/index.js` with three endpoints:

1. **createRazorpayOrder** - Creates a Razorpay order when user initiates payment
2. **verifyRazorpayPayment** - Verifies payment signature and marks booking as paid
3. **markPaymentFailed** - Handles failed payment scenarios

### Deploy Functions:

```bash
# Navigate to functions folder
cd functions

# Install dependencies (if not already done)
npm install

# Deploy all functions to Firebase
firebase deploy --only functions
```

**Expected Output:**

```
✔ functions: Deployed successfully
✔ createRazorpayOrder deployed
✔ verifyRazorpayPayment deployed
✔ markPaymentFailed deployed
```

After deployment, note the function URLs (they will look like):

- `https://us-central1-expresscar-75596.cloudfunctions.net/createRazorpayOrder`
- `https://us-central1-expresscar-75596.cloudfunctions.net/verifyRazorpayPayment`
- `https://us-central1-expresscar-75596.cloudfunctions.net/markPaymentFailed`

---

## 🚀 Step 3: Run Flutter App with Payment Configuration

The app needs Razorpay configuration passed at runtime using `--dart-define` flags.

### Development Build (Debug):

```bash
flutter run -d windows ^
  --dart-define=RAZORPAY_KEY_ID=rzp_test_SiOMYi5nmRkGyl ^
  --dart-define=PAYMENT_CREATE_ORDER_URL=https://us-central1-expresscar-75596.cloudfunctions.net/createRazorpayOrder ^
  --dart-define=PAYMENT_VERIFY_URL=https://us-central1-expresscar-75596.cloudfunctions.net/verifyRazorpayPayment ^
  --dart-define=PAYMENT_FAILURE_URL=https://us-central1-expresscar-75596.cloudfunctions.net/markPaymentFailed
```

### Android Build:

```bash
flutter build apk --release ^
  --dart-define=RAZORPAY_KEY_ID=rzp_test_SiOMYi5nmRkGyl ^
  --dart-define=PAYMENT_CREATE_ORDER_URL=https://us-central1-expresscar-75596.cloudfunctions.net/createRazorpayOrder ^
  --dart-define=PAYMENT_VERIFY_URL=https://us-central1-expresscar-75596.cloudfunctions.net/verifyRazorpayPayment ^
  --dart-define=PAYMENT_FAILURE_URL=https://us-central1-expresscar-75596.cloudfunctions.net/markPaymentFailed
```

### iOS Build:

```bash
flutter build ipa --release ^
  --dart-define=RAZORPAY_KEY_ID=rzp_test_SiOMYi5nmRkGyl ^
  --dart-define=PAYMENT_CREATE_ORDER_URL=https://us-central1-expresscar-75596.cloudfunctions.net/createRazorpayOrder ^
  --dart-define=PAYMENT_VERIFY_URL=https://us-central1-expresscar-75596.cloudfunctions.net/verifyRazorpayPayment ^
  --dart-define=PAYMENT_FAILURE_URL=https://us-central1-expresscar-75596.cloudfunctions.net/markPaymentFailed
```

---

## 🧪 Step 4: Test Payment Flow

### Test Card Numbers (Razorpay Sandbox):

**Success:**

- Card: `4111 1111 1111 1111`
- Expiry: Any future date
- CVV: Any 3 digits

**Failure:**

- Card: `4222 2222 2222 2222`
- Expiry: Any future date
- CVV: Any 3 digits

### Payment Flow in App:

1. **Sign In** → User must be authenticated
2. **Browse Cars** → Select a car and create booking
3. **Booking Summary** → Shows booking details and price
4. **Payment Page** → Click "Pay Online"
5. **Razorpay Checkout** → Enter test card details
6. **Verification** → Backend verifies payment signature
7. **Success** → Booking marked as paid, can add rating

---

## 📱 Step 5: What Happens Behind the Scenes

### When User Clicks "Pay Online":

```
App (Flutter)
    ↓
    POST to PAYMENT_CREATE_ORDER_URL
    {booking_id, amount, currency}
    ↓
Cloud Functions (createRazorpayOrder)
    ↓
    Validates Firebase Auth Token
    ↓
    Verifies user owns booking
    ↓
    Creates Razorpay Order
    ↓
    Returns order_id to app
    ↓
    App Opens Razorpay Checkout UI
    ↓
    User Enters Payment Details
    ↓
    Razorpay Processes Payment
    ↓
    Success Callback → POST to PAYMENT_VERIFY_URL
    ↓
Cloud Functions (verifyRazorpayPayment)
    ↓
    Verifies HMAC Signature
    ↓
    Updates Firestore: payment_status = "paid"
    ↓
    Returns success to app
    ↓
    App Shows "Payment Verified"
    ↓
    Booking Ready for Rating & Review
```

---

## 💾 Booking Document Structure (Firestore)

After successful payment, booking document will have:

```javascript
{
  booking_id: "booking_123",
  user_id: "user_uid",
  car_id: 5,
  car_name: "Audi A6",
  total_amount: 8000,

  // Payment Fields (Auto-filled)
  payment_status: "paid",           // "pending", "paid", or "failed"
  payment_method: "online",         // "cash_on_pickup" or "online"
  payment_id: "pay_XXXXX",         // Razorpay payment ID
  payment_order_id: "order_XXXXX", // Razorpay order ID
  transaction_ref: "RPAY_pay_XXXXX",
  payment_amount: 8000,
  paid_at: "2026-05-02T14:30:00Z",
  payment_updated_at: "2026-05-02T14:30:00Z",

  // Rating & Review (Only after payment_status = "paid")
  user_rating: 5,
  user_review: "Great car, excellent service!",
  reviewed_at: "2026-05-02T15:00:00Z"
}
```

---

## 🔐 Security Features Built In

✅ Firebase ID Token verification on every payment request
✅ User owns booking validation (booking_id must belong to user)
✅ HMAC signature verification (prevents tampering)
✅ Payment state tracking (pending → paid/failed)
✅ Firestore rules prevent direct booking modifications

---

## 🛠️ Troubleshooting

### Error: "Missing payment URLs"

**Solution:** Run flutter with all 4 `--dart-define` flags. Check the command in Step 3.

### Error: "Razorpay key is not configured"

**Solution:** Ensure functions are deployed with `.env` file. Check Firebase Cloud Functions logs.

### Error: "Payment verification failed"

**Solution:** Check function logs in Firebase Console → Functions → Logs

### Payment appears in Razorpay but not in Firestore

**Solution:** Check verifyRazorpayPayment function logs. User might not own the booking.

---

## 📊 Monitoring Payments

### Firebase Console:

- **Cloud Functions** → View logs for payment requests
- **Firestore** → Check `bookings` collection for payment_status
- **Authentication** → Verify users are properly authenticated

### Razorpay Dashboard:

- https://dashboard.razorpay.com
- View all transactions, refunds, and payment trends

---

## 🔄 Next Steps

1. ✅ Deploy functions: `firebase deploy --only functions`
2. ✅ Get function URLs from Firebase Console
3. ✅ Run flutter with dart-defines (use command from Step 3)
4. ✅ Test with test card numbers (Step 4)
5. ✅ Monitor payments in Firebase Console
6. 📅 When ready for production: Replace test keys with live keys and redeploy

---

## 📞 Support

For issues:

1. Check Firebase Console → Cloud Functions → Logs
2. Check Flutter console for network errors
3. Verify all dart-define flags are passed correctly
4. Confirm user is signed in before payment

**Razorpay Docs:** https://razorpay.com/docs/payments/
**Firebase Functions Docs:** https://firebase.google.com/docs/functions/

---

**Last Updated:** May 2, 2026
**Status:** ✅ Ready for Testing
