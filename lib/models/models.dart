import 'package:cloud_firestore/cloud_firestore.dart';

class User {
  final String id;
  final String name;
  final String? profileImageUrl;
  final String about;
  final String phoneNumber;
  final bool isTitanElite;

  User({
    required this.id,
    required this.name,
    this.profileImageUrl,
    this.about = "Hey there! I am using WhatsApp.",
    this.phoneNumber = "",
    this.isTitanElite = false,
  });

  factory User.fromMap(Map<String, dynamic> map, String id) {
    return User(
      id: id,
      name: map['name'] ?? '',
      profileImageUrl: map['photoUrl'],
      about: map['about'] ?? "Hey there! I am using WhatsApp.",
      phoneNumber: map['phoneNumber'] ?? '',
      isTitanElite: map['isTitanElite'] ?? false,
    );
  }
}

class Message {
  final String id;
  final String senderId;
  final String text;
  final DateTime timestamp;
  final bool isRead;
  final bool isEdited;
  final bool isPinned;
  final String type; // 'text', 'image', 'invoice', 'poll', 'contact'
  final Map<String, dynamic>? metadata;

  Message({
    required this.id,
    required this.senderId,
    required this.text,
    required this.timestamp,
    this.isRead = false,
    this.isEdited = false,
    this.isPinned = false,
    this.type = 'text',
    this.metadata,
  });
}

class Chat {
  final String id;
  final List<String> members;
  final Message? lastMessage;
  final bool isGroup;
  final String? groupName;
  final bool isPinned;

  Chat({
    required this.id,
    required this.members,
    this.lastMessage,
    this.isGroup = false,
    this.groupName,
    this.isPinned = false,
  });
}

class Community {
  final String id;
  final String name;
  final String description;
  final List<String> groupIds;
  final List<CommunityChannel> channels;
  final Map<String, String> roles; // userId: role

  Community({
    required this.id,
    required this.name,
    required this.description,
    required this.groupIds,
    this.channels = const [],
    this.roles = const {},
  });

  factory Community.fromMap(Map<String, dynamic> map, String id) {
    return Community(
      id: id,
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      groupIds: List<String>.from(map['groupIds'] ?? []),
      channels: (map['channels'] as List? ?? [])
          .map((c) => CommunityChannel.fromMap(c))
          .toList(),
      roles: Map<String, String>.from(map['roles'] ?? {}),
    );
  }
}

class CommunityChannel {
  final String id;
  final String name;
  final String type; // 'text', 'voice', 'announcement'

  CommunityChannel({
    required this.id,
    required this.name,
    required this.type,
  });

  Map<String, dynamic> toMap() {
    return {'id': id, 'name': name, 'type': type};
  }

  factory CommunityChannel.fromMap(Map<String, dynamic> map) {
    return CommunityChannel(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      type: map['type'] ?? 'text',
    );
  }
}

class MarketplaceItem {
  final String id;
  final String sellerId;
  final String title;
  final double price;
  final String description;
  final String category;
  final String location;
  final double? lat;
  final double? lng;
  final String imageUrl;
  final String? imagePublicId;
  final List<String> moreImages;
  final String? videoUrl;
  final List<String> aiTags;
  final DateTime createdAt;
  // Car specific
  final String? brand;
  final String? model;
  final String? year;
  final Map<String, String>? specs;
  final bool isPromoted;
  final bool isVerifiedSeller;

  MarketplaceItem({
    required this.id,
    required this.sellerId,
    required this.title,
    required this.price,
    required this.description,
    required this.category,
    required this.location,
    this.lat,
    this.lng,
    required this.imageUrl,
    this.imagePublicId,
    this.moreImages = const [],
    this.videoUrl,
    this.aiTags = const [],
    required this.createdAt,
    this.brand,
    this.model,
    this.year,
    this.specs,
    this.isPromoted = false,
    this.isVerifiedSeller = false,
  });

  factory MarketplaceItem.fromMap(String id, Map<String, dynamic> map) {
    return MarketplaceItem(
      id: id,
      sellerId: map['sellerId'] ?? '',
      title: map['title'] ?? '',
      price: double.tryParse(map['price'].toString()) ?? 0.0,
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      location: map['location'] ?? '',
      lat: map['lat'] != null ? double.tryParse(map['lat'].toString()) : null,
      lng: map['lng'] != null ? double.tryParse(map['lng'].toString()) : null,
      imageUrl: map['imageUrl'] ?? '',
      imagePublicId: map['imagePublicId'],
      moreImages: List<String>.from(map['moreImages'] ?? []),
      videoUrl: map['videoUrl'],
      aiTags: List<String>.from(map['aiTags'] ?? []),
      createdAt: (map['createdAt'] as dynamic)?.toDate() ?? DateTime.now(),
      brand: map['brand'],
      model: map['model'],
      year: map['year'],
      specs: map['specs'] != null ? Map<String, String>.from(map['specs']) : null,
      isPromoted: map['isPromoted'] ?? false,
      isVerifiedSeller: map['isVerifiedSeller'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sellerId': sellerId,
      'title': title,
      'price': price,
      'description': description,
      'category': category,
      'location': location,
      'lat': lat,
      'lng': lng,
      'imageUrl': imageUrl,
      'imagePublicId': imagePublicId,
      'moreImages': moreImages,
      'videoUrl': videoUrl,
      'createdAt': FieldValue.serverTimestamp(),
      'brand': brand,
      'model': model,
      'year': year,
      'specs': specs,
    };
  }
}

class MarketOrder {
  final String id;
  final String buyerId;
  final String sellerId;
  final String itemId;
  final String itemTitle;
  final double amount;
  final String status; // 'Pending', 'Paid', 'Shipped', 'Completed'
  final DateTime timestamp;

  MarketOrder({
    required this.id,
    required this.buyerId,
    required this.sellerId,
    required this.itemId,
    required this.itemTitle,
    required this.amount,
    required this.status,
    required this.timestamp,
  });

  factory MarketOrder.fromMap(Map<String, dynamic> map, String id) {
    return MarketOrder(
      id: id,
      buyerId: map['buyerId'] ?? '',
      sellerId: map['sellerId'] ?? '',
      itemId: map['itemId'] ?? '',
      itemTitle: map['itemTitle'] ?? '',
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      status: map['status'] ?? 'Pending',
      timestamp: (map['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}

class Transaction {
  final String id;
  final String type; // 'send', 'receive', 'airtime', 'ajo'
  final double amount;
  final String recipient;
  final DateTime timestamp;
  final String status;

  Transaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.recipient,
    required this.timestamp,
    this.status = 'Completed',
  });
}

class AjoGroup {
  final String id;
  final String name;
  final String creatorId;
  final double contributionAmount;
  final String contributionCurrency; 
  final String frequencyType; // 'Daily', 'Weekly', 'Monthly'
  final int frequencyDays;
  final int totalCycles; // How many times contributors will pay (e.g., 12 months)
  final double? totalTargetAmount;
  final List<String> members;
  final Map<String, bool> payoutStatus; 
  final DateTime createdAt;
  final DateTime? nextPayoutDate;
  final int currentTurnIndex;
  
  // Group-specific Receiving Account
  final String? bankName;
  final String? accountNumber;
  final String? accountName;
  final String? rules;

  AjoGroup({
    required this.id,
    required this.name,
    required this.creatorId,
    required this.contributionAmount,
    this.contributionCurrency = 'NGN',
    required this.frequencyType,
    required this.frequencyDays,
    required this.totalCycles,
    this.totalTargetAmount,
    required this.members,
    required this.payoutStatus,
    required this.createdAt,
    this.nextPayoutDate,
    this.currentTurnIndex = 0,
    this.bankName,
    this.accountNumber,
    this.accountName,
    this.rules,
  });

  factory AjoGroup.fromMap(Map<String, dynamic> map, String id) {
    return AjoGroup(
      id: id,
      name: map['name'] ?? '',
      creatorId: map['creatorId'] ?? '',
      contributionAmount: double.tryParse(map['contributionAmount'].toString()) ?? 0.0,
      contributionCurrency: map['contributionCurrency'] ?? 'NGN',
      frequencyType: map['frequencyType'] ?? 'Monthly',
      frequencyDays: map['frequencyDays'] ?? 30,
      totalCycles: map['totalCycles'] ?? 1,
      totalTargetAmount: map['totalTargetAmount'] != null ? double.tryParse(map['totalTargetAmount'].toString()) : null,
      members: List<String>.from(map['members'] ?? []),
      payoutStatus: Map<String, bool>.from(map['payoutStatus'] ?? {}),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      nextPayoutDate: (map['nextPayoutDate'] as Timestamp?)?.toDate(),
      currentTurnIndex: map['currentTurnIndex'] ?? 0,
      bankName: map['bankName'],
      accountNumber: map['accountNumber'],
      accountName: map['accountName'],
      rules: map['rules'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'creatorId': creatorId,
      'contributionAmount': contributionAmount,
      'contributionCurrency': contributionCurrency,
      'frequencyType': frequencyType,
      'frequencyDays': frequencyDays,
      'totalCycles': totalCycles,
      'totalTargetAmount': totalTargetAmount,
      'members': members,
      'payoutStatus': payoutStatus,
      'createdAt': FieldValue.serverTimestamp(),
      'nextPayoutDate': nextPayoutDate != null ? Timestamp.fromDate(nextPayoutDate!) : null,
      'currentTurnIndex': currentTurnIndex,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'accountName': accountName,
      'rules': rules,
    };
  }
}

class CatalogItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;

  CatalogItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'description': description,
      'price': price,
      'imageUrl': imageUrl,
    };
  }

  factory CatalogItem.fromMap(Map<String, dynamic> map) {
    return CatalogItem(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      price: double.tryParse(map['price'].toString()) ?? 0.0,
      imageUrl: map['imageUrl'] ?? '',
    );
  }
}

class Invoice {
  final String id;
  final String itemName;
  final double amount;
  final DateTime dueDate;
  final String status; // 'Pending', 'Paid'

  Invoice({
    required this.id,
    required this.itemName,
    required this.amount,
    required this.dueDate,
    this.status = 'Pending',
  });

  Map<String, dynamic> toMap() {
    return {
      'itemName': itemName,
      'amount': amount,
      'dueDate': dueDate.toIso8601String(),
      'status': status,
    };
  }

  factory Invoice.fromMap(Map<String, dynamic> map) {
    return Invoice(
      id: map['id'] ?? '',
      itemName: map['itemName'] ?? '',
      amount: double.tryParse(map['amount'].toString()) ?? 0.0,
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : DateTime.now(),
      status: map['status'] ?? 'Pending',
    );
  }
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> options;
  final String creatorId;
  final DateTime createdAt;

  Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.creatorId,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'question': question,
      'options': options.map((e) => e.toMap()).toList(),
      'creatorId': creatorId,
      'createdAt': createdAt.toIso8601String(),
    };
  }

  factory Poll.fromMap(Map<String, dynamic> map) {
    return Poll(
      id: map['id'] ?? '',
      question: map['question'] ?? '',
      options: (map['options'] as List).map((e) => PollOption.fromMap(e)).toList(),
      creatorId: map['creatorId'] ?? '',
      createdAt: map['createdAt'] != null ? DateTime.parse(map['createdAt']) : DateTime.now(),
    );
  }
}

class PollOption {
  final String text;
  final List<String> voterIds;

  PollOption({required this.text, this.voterIds = const []});

  Map<String, dynamic> toMap() {
    return {
      'text': text,
      'voterIds': voterIds,
    };
  }

  factory PollOption.fromMap(Map<String, dynamic> map) {
    return PollOption(
      text: map['text'] ?? '',
      voterIds: List<String>.from(map['voterIds'] ?? []),
    );
  }
}

class Call {
  final String id;
  final String userId;
  final bool isVideo;
  final bool isIncoming;
  final bool isMissed;
  final DateTime timestamp;

  Call({
    required this.id,
    required this.userId,
    this.isVideo = false,
    this.isIncoming = true,
    this.isMissed = false,
    required this.timestamp,
  });
}

class PersonalSavings {
  final String id;
  final String userId;
  final String name;
  final double targetAmount;
  final double currentBalance;
  final int durationMonths;
  final String frequency; // 'Daily', 'Weekly', 'Monthly'
  final DateTime startDate;
  final DateTime targetDate;
  final String bankName;
  final String accountNumber;
  final String nextOfKinPhone;
  final bool isVerified; // ₦500 verification
  final bool isBvnVerified;
  final int tier; // 1: Newbie, 2: Bronze, 3: Silver
  final int points;
  final bool isLocked;

  PersonalSavings({
    required this.id,
    required this.userId,
    required this.name,
    required this.targetAmount,
    this.currentBalance = 0.0,
    required this.durationMonths,
    required this.frequency,
    required this.startDate,
    required this.targetDate,
    required this.bankName,
    required this.accountNumber,
    required this.nextOfKinPhone,
    this.isVerified = false,
    this.isBvnVerified = false,
    this.tier = 1,
    this.points = 150,
    this.isLocked = false,
  });

  factory PersonalSavings.fromMap(Map<String, dynamic> map, String id) {
    return PersonalSavings(
      id: id,
      userId: map['userId'] ?? '',
      name: map['name'] ?? '',
      targetAmount: (map['targetAmount'] ?? 0.0).toDouble(),
      currentBalance: (map['currentBalance'] ?? 0.0).toDouble(),
      durationMonths: map['durationMonths'] ?? 1,
      frequency: map['frequency'] ?? 'Monthly',
      startDate: (map['startDate'] as Timestamp).toDate(),
      targetDate: (map['targetDate'] as Timestamp).toDate(),
      bankName: map['bankName'] ?? '',
      accountNumber: map['accountNumber'] ?? '',
      nextOfKinPhone: map['nextOfKinPhone'] ?? '',
      isVerified: map['isVerified'] ?? false,
      isBvnVerified: map['isBvnVerified'] ?? false,
      tier: map['tier'] ?? 1,
      points: map['points'] ?? 150,
      isLocked: map['isLocked'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'name': name,
      'targetAmount': targetAmount,
      'currentBalance': currentBalance,
      'durationMonths': durationMonths,
      'frequency': frequency,
      'startDate': startDate,
      'targetDate': targetDate,
      'bankName': bankName,
      'accountNumber': accountNumber,
      'nextOfKinPhone': nextOfKinPhone,
      'isVerified': isVerified,
      'isBvnVerified': isBvnVerified,
      'tier': tier,
      'points': points,
      'isLocked': isLocked,
    };
  }
}

