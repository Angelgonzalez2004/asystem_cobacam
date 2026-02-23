// Importa los scripts de Firebase necesarios
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-app-compat.js');
importScripts('https://www.gstatic.com/firebasejs/9.22.1/firebase-messaging-compat.js');

// Configuración de Firebase sacada de firebase_options.dart
firebase.initializeApp({
  apiKey: "AIzaSyBCPbd2VOinSwg2FkosSKQmzRBi1RkbyMw",
  authDomain: "asystemcobacam.firebaseapp.com",
  databaseURL: "https://asystemcobacam-default-rtdb.firebaseio.com/",
  projectId: "asystemcobacam",
  storageBucket: "asystemcobacam.firebasestorage.app",
  messagingSenderId: "847754643180",
  appId: "1:847754643180:web:6d9ad455315a565bcdc7c9"
});

const messaging = firebase.messaging();

// Manejador de mensajes en segundo plano
messaging.onBackgroundMessage(function(payload) {
  console.log('[firebase-messaging-sw.js] Mensaje recibido en segundo plano: ', payload);
  
  const notificationTitle = payload.notification.title;
  const notificationOptions = {
    body: payload.notification.body,
    icon: '/favicon.png',
    data: payload.data
  };

  return self.registration.showNotification(notificationTitle, notificationOptions);
});
