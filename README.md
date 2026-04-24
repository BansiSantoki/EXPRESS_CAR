# express_car

A new Flutter project.

## Razorpay Payment Setup

### 1) Install app dependency

- Add dependency in `pubspec.yaml`: `razorpay_flutter`
- Run: `flutter pub get`

### 2) Deploy secure payment backend (Cloud Functions)

- Functions source is in `functions/`
- Install dependencies:
  - `cd functions`
  - `npm install`
- Create `functions/.env` and set:
  - `RAZORPAY_KEY_ID=your_key_id`
  - `RAZORPAY_KEY_SECRET=your_key_secret`
- Deploy:
  - `firebase deploy --only functions`

Deployed endpoints expected by the app:

- `createRazorpayOrder`
- `verifyRazorpayPayment`
- `markPaymentFailed`

### 3) Run Flutter app with payment defines

Pass these on run/build:

- `--dart-define=RAZORPAY_KEY_ID=YOUR_KEY_ID`
- `--dart-define=PAYMENT_CREATE_ORDER_URL=https://<region>-<project>.cloudfunctions.net/createRazorpayOrder`
- `--dart-define=PAYMENT_VERIFY_URL=https://<region>-<project>.cloudfunctions.net/verifyRazorpayPayment`
- `--dart-define=PAYMENT_FAILURE_URL=https://<region>-<project>.cloudfunctions.net/markPaymentFailed`

### 4) Booking payment states

- New booking creates payment state as `pending`
- After verified success, backend updates booking to `paid`
- On failure, backend marks `failed`
- User can submit rating/review only after `paid`
