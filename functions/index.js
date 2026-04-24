const crypto = require('crypto');
const Razorpay = require('razorpay');
const { onRequest } = require('firebase-functions/v2/https');
const logger = require('firebase-functions/logger');
const admin = require('firebase-admin');

admin.initializeApp();

const db = admin.firestore();

const razorpayKeyId = process.env.RAZORPAY_KEY_ID || '';
const razorpayKeySecret = process.env.RAZORPAY_KEY_SECRET || '';

const razorpay = razorpayKeyId && razorpayKeySecret
  ? new Razorpay({ key_id: razorpayKeyId, key_secret: razorpayKeySecret })
  : null;

function withCors(response) {
  response.set('Access-Control-Allow-Origin', '*');
  response.set('Access-Control-Allow-Headers', 'Content-Type,Authorization');
  response.set('Access-Control-Allow-Methods', 'POST,OPTIONS');
}

async function verifyFirebaseToken(request) {
  const authHeader = request.get('Authorization') || '';
  if (!authHeader.startsWith('Bearer ')) {
    return null;
  }

  const token = authHeader.substring('Bearer '.length).trim();
  if (!token) {
    return null;
  }

  try {
    return await admin.auth().verifyIdToken(token);
  } catch (_) {
    return null;
  }
}

exports.createRazorpayOrder = onRequest(async (request, response) => {
  withCors(response);

  if (request.method === 'OPTIONS') {
    response.status(204).send('');
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (!razorpay) {
    response.status(500).json({ error: 'Razorpay keys are not configured in function environment.' });
    return;
  }

  try {
    const decoded = await verifyFirebaseToken(request);
    if (!decoded) {
      response.status(401).json({ error: 'Unauthorized: missing/invalid Firebase token.' });
      return;
    }

    const body = request.body || {};
    const bookingId = (body.booking_id || '').toString().trim();
    const amount = Number(body.amount || 0);
    const currency = (body.currency || 'INR').toString();

    if (!bookingId || !Number.isInteger(amount) || amount <= 0) {
      response.status(400).json({ error: 'Invalid booking_id or amount.' });
      return;
    }

    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await bookingRef.get();

    if (!bookingSnap.exists) {
      response.status(404).json({ error: 'Booking not found.' });
      return;
    }

    const bookingData = bookingSnap.data() || {};
    if (bookingData.userId !== decoded.uid) {
      response.status(403).json({ error: 'Booking does not belong to this user.' });
      return;
    }

    const order = await razorpay.orders.create({
      amount,
      currency,
      receipt: `booking_${bookingId}`,
      notes: {
        booking_id: bookingId,
        user_id: decoded.uid,
      },
    });

    await bookingRef.set({
      payment_status: 'pending',
      payment_method: 'online',
      payment_amount: amount / 100,
      payment_order_id: order.id,
      transaction_ref: '',
      payment_time: null,
      paid_at: null,
      payment_id: '',
      payment_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    response.status(200).json({
      order_id: order.id,
      amount: order.amount,
      currency: order.currency,
      key_id: razorpayKeyId,
    });
  } catch (error) {
    logger.error('createRazorpayOrder failed', error);
    response.status(500).json({ error: error.message || 'Failed to create order.' });
  }
});

exports.verifyRazorpayPayment = onRequest(async (request, response) => {
  withCors(response);

  if (request.method === 'OPTIONS') {
    response.status(204).send('');
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (!razorpayKeySecret) {
    response.status(500).json({ error: 'Razorpay secret is not configured.' });
    return;
  }

  try {
    const decoded = await verifyFirebaseToken(request);
    if (!decoded) {
      response.status(401).json({ error: 'Unauthorized: missing/invalid Firebase token.' });
      return;
    }

    const body = request.body || {};
    const bookingId = (body.booking_id || '').toString().trim();
    const paymentId = (body.razorpay_payment_id || '').toString().trim();
    const orderId = (body.razorpay_order_id || '').toString().trim();
    const signature = (body.razorpay_signature || '').toString().trim();

    if (!bookingId || !paymentId || !orderId || !signature) {
      response.status(400).json({ error: 'Missing required Razorpay verification payload.' });
      return;
    }

    const digest = crypto
      .createHmac('sha256', razorpayKeySecret)
      .update(`${orderId}|${paymentId}`)
      .digest('hex');

    if (digest !== signature) {
      response.status(400).json({ error: 'Invalid payment signature.' });
      return;
    }

    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await bookingRef.get();

    if (!bookingSnap.exists) {
      response.status(404).json({ error: 'Booking not found.' });
      return;
    }

    const bookingData = bookingSnap.data() || {};
    if (bookingData.userId !== decoded.uid) {
      response.status(403).json({ error: 'Booking does not belong to this user.' });
      return;
    }

    await bookingRef.set({
      payment_status: 'paid',
      payment_method: 'online',
      payment_id: paymentId,
      payment_order_id: orderId,
      transaction_ref: `RPAY-${paymentId}`,
      payment_time: admin.firestore.FieldValue.serverTimestamp(),
      paid_at: admin.firestore.FieldValue.serverTimestamp(),
      payment_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    response.status(200).json({ success: true, booking_id: bookingId });
  } catch (error) {
    logger.error('verifyRazorpayPayment failed', error);
    response.status(500).json({ error: error.message || 'Verification failed.' });
  }
});

exports.markPaymentFailed = onRequest(async (request, response) => {
  withCors(response);

  if (request.method === 'OPTIONS') {
    response.status(204).send('');
    return;
  }

  if (request.method !== 'POST') {
    response.status(405).json({ error: 'Method not allowed' });
    return;
  }

  try {
    const decoded = await verifyFirebaseToken(request);
    if (!decoded) {
      response.status(401).json({ error: 'Unauthorized: missing/invalid Firebase token.' });
      return;
    }

    const body = request.body || {};
    const bookingId = (body.booking_id || '').toString().trim();
    const paymentId = (body.payment_id || '').toString().trim();
    const reason = (body.reason || 'Payment failed').toString().trim();

    if (!bookingId) {
      response.status(400).json({ error: 'booking_id is required.' });
      return;
    }

    const bookingRef = db.collection('bookings').doc(bookingId);
    const bookingSnap = await bookingRef.get();

    if (!bookingSnap.exists) {
      response.status(404).json({ error: 'Booking not found.' });
      return;
    }

    const bookingData = bookingSnap.data() || {};
    if (bookingData.userId !== decoded.uid) {
      response.status(403).json({ error: 'Booking does not belong to this user.' });
      return;
    }

    await bookingRef.set({
      payment_status: 'failed',
      payment_id: paymentId,
      payment_failure_reason: reason,
      payment_updated_at: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });

    response.status(200).json({ success: true, booking_id: bookingId });
  } catch (error) {
    logger.error('markPaymentFailed failed', error);
    response.status(500).json({ error: error.message || 'Failed to update payment status.' });
  }
});
