const { onDocumentWritten, onDocumentCreated } = require("firebase-functions/v2/firestore");
const { onSchedule } = require("firebase-functions/v2/scheduler");
const admin = require("firebase-admin");

admin.initializeApp();

// Ortak Bildirim Ayarları (Ses ve Titreşim İçin)
const commonAndroidConfig = {
    priority: "high",
    notification: {
        sound: "default",
        defaultSound: true,
        defaultVibrateTimings: true,
        clickAction: "FLUTTER_NOTIFICATION_CLICK",
        channelId: "mykoc_channel", // Flutter tarafındakiyle birebir aynı olmalı
    },
};

const commonApnsConfig = {
    payload: {
        aps: {
            sound: "default",
            critical: true, // Bazı durumlarda sessiz modu bile deler
            badge: 1,
        },
    },
};

// --- 1. DUYURU BİLDİRİMİ ---
exports.sendannouncementnotification = onDocumentWritten("announcements/{announcementId}", async (event) => {
    const beforeSnapshot = event.data.before;
    const afterSnapshot = event.data.after;

    if (!afterSnapshot || !afterSnapshot.exists) return null;

    const newValue = afterSnapshot.data();
    const oldValue = beforeSnapshot.exists ? beforeSnapshot.data() : null;

    let notificationTitle = !oldValue ? "📣 Yeni Duyuru!" : "📣 Duyuru Güncellemesi";
    const notificationBody = `${newValue.title}\n${newValue.description}`;

    try {
        const studentsSnapshot = await admin.firestore().collection("students")
            .where("classId", "==", newValue.classId).get();

        if (studentsSnapshot.empty) return null;

        const tokens = [];
        for (const studentDoc of studentsSnapshot.docs) {
            const uid = studentDoc.data().uid;
            const tokenDoc = await admin.firestore().collection("fcmTokens").doc(uid).get();
            if (tokenDoc.exists) tokens.push(tokenDoc.data().token);
        }

        if (tokens.length === 0) return null;

        const message = {
            notification: { title: notificationTitle, body: notificationBody },
            android: commonAndroidConfig,
            apns: commonApnsConfig,
            tokens: tokens,
            data: { type: "announcement", classId: newValue.classId }
        };

        await admin.messaging().sendEachForMulticast(message);
        return null;
    } catch (error) {
        console.error("❌ Duyuru hatası:", error);
        return null;
    }
});

// --- 2. GÖREV (TASK) BİLDİRİMİ ---
exports.sendtasknotification = onDocumentCreated("tasks/{taskId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const taskData = snapshot.data();
    const assignedStudents = taskData.assignedStudents || [];

    if (assignedStudents.length === 0) return null;

    try {
        const tokens = [];
        for (const uid of assignedStudents) {
            const tokenDoc = await admin.firestore().collection("fcmTokens").doc(uid).get();
            if (tokenDoc.exists && tokenDoc.data().token) tokens.push(tokenDoc.data().token);
        }

        if (tokens.length === 0) return null;

        const message = {
            notification: {
                title: "📅 Yeni Ödev Atandı!",
                body: `${taskData.title}\n${taskData.description}`
            },
            android: commonAndroidConfig,
            apns: commonApnsConfig,
            tokens: tokens,
            data: { type: "task", taskId: event.params.taskId }
        };

        await admin.messaging().sendEachForMulticast(message);
        return null;
    } catch (error) {
        console.error("❌ Ödev hatası:", error);
        return null;
    }
});

// --- 3. TAKVİM VE GÜNLÜK HATIRLATMA ---
exports.dailyremindercheck = onSchedule("0 6 * * *", async (event) => {
    const now = new Date();
    const startOfDay = admin.firestore.Timestamp.fromDate(new Date(now.setHours(0, 0, 0, 0)));
    const endOfDay = admin.firestore.Timestamp.fromDate(new Date(now.setHours(23, 59, 59, 999)));

    try {
        const notesSnapshot = await admin.firestore().collection("calendar_notes")
            .where("date", ">=", startOfDay)
            .where("date", "<=", endOfDay).get();

        for (const doc of notesSnapshot.docs) {
            const note = doc.data();
            await sendFullNotification(note.userId, "📝 Bugün İçin Notun Var", note.content, "calendar");
        }

        const tasksSnapshot = await admin.firestore().collection("tasks")
            .where("dueDate", ">=", startOfDay)
            .where("dueDate", "<=", endOfDay).get();

        for (const doc of tasksSnapshot.docs) {
            const task = doc.data();
            const students = task.assignedStudents || [];
            for (const uid of students) {
                await sendFullNotification(uid, "⏳ Ödev İçin Son Gün!", `"${task.title}" ödevinin teslim tarihi bugün.`, "task");
            }
        }
    } catch (error) {
        console.error("❌ Hatırlatma hatası:", error);
    }
});

// --- 4. MESAJ BİLDİRİMİ ---
exports.sendmessagenotification = onDocumentCreated("chatRooms/{roomId}/messages/{messageId}", async (event) => {
    const snapshot = event.data;
    if (!snapshot) return null;

    const message = snapshot.data();
    const roomId = event.params.roomId;
    const senderId = message.senderId;

    try {
        // 1. Sohbet odası verilerini çek
        const chatRoomDoc = await admin.firestore().collection("chatRooms").doc(roomId).get();
        if (!chatRoomDoc.exists) return null;

        const chatRoomData = chatRoomDoc.data();
        const participants = chatRoomData.participantIds || [];

        // 2. Odadaki tüm katılımcılara bak (gönderen hariç)
        for (const receiverId of participants) {
            if (receiverId === senderId) continue;

            // KRİTİK KONTROL: Kullanıcı o an bu sohbetin içinde mi?
            // Uygulama tarafında sohbet odasına girince 'activeChatRoomId' alanını güncelleyeceğiz.
            const userDoc = await admin.firestore().collection("users").doc(receiverId).get();
            const activeRoomId = userDoc.data()?.activeChatRoomId;

            if (activeRoomId === roomId) {
                console.log(`🔇 Kullanıcı (${receiverId}) odada aktif, bildirim susturuldu.`);
                continue;
            }

            // 3. Bildirim gönder
            const tokenDoc = await admin.firestore().collection("fcmTokens").doc(receiverId).get();
            if (tokenDoc.exists && tokenDoc.data().token) {
                const messagePayload = {
                    notification: {
                        title: chatRoomData.type === "class_group" ? `${chatRoomData.name}` : `${message.senderName}`,
                        body: message.fileUrl ? "📎 Bir dosya gönderdi" : message.messageText
                    },
                    android: {
                        priority: "high",
                        notification: {
                            sound: "default",
                            channelId: "mykoc_channel",
                            tag: roomId // Aynı odadan gelen mesajları gruplar
                        }
                    },
                    token: tokenDoc.data().token,
                    data: {
                        type: "chat",
                        chatRoomId: roomId
                    }
                };
                await admin.messaging().send(messagePayload);
            }
        }
        return null;
    } catch (error) {
        console.error("❌ Mesaj bildirimi hatası:", error);
        return null;
    }
});

async function sendFullNotification(uid, title, body, type) {
    const tokenDoc = await admin.firestore().collection("fcmTokens").doc(uid).get();
    if (!tokenDoc.exists) return;

    const message = {
        notification: { title, body },
        android: commonAndroidConfig,
        apns: commonApnsConfig,
        token: tokenDoc.data().token,
        data: { type: type }
    };

    try {
        await admin.messaging().send(message);
    } catch (e) {
        console.error(`Hata (${uid}):`, e);
    }
}