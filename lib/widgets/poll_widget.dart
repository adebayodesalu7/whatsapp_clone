import 'package:flutter/material.dart';
import '../models/models.dart';

class PollWidget extends StatelessWidget {
  final Poll poll;
  final String currentUserId;
  final Function(int) onVote;

  const PollWidget({
    super.key,
    required this.poll,
    required this.currentUserId,
    required this.onVote,
  });

  @override
  Widget build(BuildContext context) {
    int totalVotes = poll.options.fold(0, (sum, item) => sum + item.voterIds.length);

    return Container(
      width: 250,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, spreadRadius: 2),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.poll, color: Color(0xFF075E54), size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.question,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...poll.options.asMap().entries.map((entry) {
            int index = entry.key;
            PollOption option = entry.value;
            bool hasVoted = option.voterIds.contains(currentUserId);
            double percentage = totalVotes == 0 ? 0 : option.voterIds.length / totalVotes;

            return Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: GestureDetector(
                onTap: () => onVote(index),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(option.text, style: TextStyle(
                          color: hasVoted ? const Color(0xFF075E54) : Colors.black87,
                          fontWeight: hasVoted ? FontWeight.bold : FontWeight.normal,
                        )),
                        Text('${(percentage * 100).toStringAsFixed(0)}%'),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: percentage,
                          child: Container(
                            height: 8,
                            decoration: BoxDecoration(
                              color: hasVoted ? const Color(0xFF25D366) : const Color(0xFF34B7F1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            );
          }),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('$totalVotes votes', style: const TextStyle(color: Colors.grey, fontSize: 12)),
              const Text('Vote to see results', style: TextStyle(color: Color(0xFF075E54), fontSize: 12, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
