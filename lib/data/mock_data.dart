import '../models/models.dart';

class MockData {
  static final List<User> users = [
    User(id: "1", name: "Alice"),
    User(id: "2", name: "Bob"),
    User(id: "3", name: "Charlie"),
  ];

  static final List<Message> messages = [
    Message(
      id: "m1",
      senderId: "1",
      text: "Hey how are you?",
      timestamp: DateTime.now().subtract(const Duration(minutes: 5)),
    ),
    Message(
      id: "m2",
      senderId: "2",
      text: "I am good, thanks!",
      timestamp: DateTime.now().subtract(const Duration(minutes: 2)),
    ),
  ];

  static final List<Chat> chats = [
    Chat(
      id: "c1",
      members: ["1", "2"],
      lastMessage: messages.last,
      isGroup: false,
    ),
    Chat(
      id: "c2",
      members: ["1", "3"],
      lastMessage: Message(
        id: "m3",
        senderId: "3",
        text: "Let's meet tomorrow",
        timestamp: DateTime.now(),
      ),
      isGroup: true,
      groupName: "Project Team",
    ),
  ];

  static final List<Community> communities = [
    Community(
      id: "com1",
      name: "Android Developers",
      description: "Group for Android enthusiasts",
      groupIds: ["c2"],
    ),
  ];

  static final List<Call> calls = [
    Call(
      id: "ca1",
      userId: "2",
      isVideo: true,
      isIncoming: true,
      timestamp: DateTime.now().subtract(const Duration(days: 1)),
    ),
    Call(
      id: "ca2",
      userId: "3",
      isIncoming: false,
      isMissed: true,
      timestamp: DateTime.now().subtract(const Duration(days: 2)),
    ),
  ];
}
