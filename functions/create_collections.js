/**
 * Firestore seeding script
 *
 * Usage:
 *  - Set `GOOGLE_APPLICATION_CREDENTIALS` to your service account JSON, or
 *  - Run this from a Firebase Function environment where application default credentials are available.
 *
 *  node create_collections.js
 */

const admin = require('firebase-admin');

try {
  admin.initializeApp();
} catch (e) {
  // ignore if already initialized
}

const db = admin.firestore();

const collections = [
  'users',
  'cars',
  'bookings',
  'fleet_items',
  'driver_documents',
];

async function ensureCollection(name) {
  console.log(`Checking collection: ${name}`);
  const snapshot = await db.collection(name).limit(1).get();
  if (!snapshot.empty) {
    console.log(`  -> Collection '${name}' already has documents, leaving unchanged.`);
    return;
  }

  // Create an initial sentinel doc for the collection
  const docRef = db.collection(name).doc('__init__');
  const seed = { createdAt: admin.firestore.FieldValue.serverTimestamp(), seeded: true };

  // Add collection-specific minimal fields for clarity
  if (name === 'users') {
    seed.displayName = 'Admin (seed)';
    seed.email = 'admin@expresscar.com';
    seed.role = 'admin';
    seed.isOnline = false;
  } else if (name === 'cars') {
    seed.title = 'Sample car (seed)';
    seed.ownerId = 'seed_owner';
    seed.pricePerDay = 1000;
    seed.available = true;
  } else if (name === 'bookings') {
    seed.userId = 'seed_user';
    seed.carId = 'seed_car';
    seed.status = 'pending';
    seed.totalAmount = 0;
  } else if (name === 'fleet_items') {
    seed.name = 'Sample fleet item';
    seed.quantity = 1;
  } else if (name === 'driver_documents') {
    seed.userId = 'seed_driver';
    seed.verified = false;
  }

  await docRef.set(seed);
  console.log(`  -> Created sentinel document __init__ in '${name}'.`);
}

async function main() {
  console.log('Starting Firestore seeding for collections:', collections.join(', '));
  for (const col of collections) {
    try {
      await ensureCollection(col);
    } catch (err) {
      console.error(`Error ensuring collection ${col}:`, err);
    }
  }
  console.log('Seeding complete.');
  process.exit(0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
