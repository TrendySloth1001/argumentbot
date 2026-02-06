import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

class HowItWorksScreen extends StatelessWidget {
  const HowItWorksScreen({super.key});

  static const Color neonGreen = Color(0xFF00FF88);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'How It Works',
          style: TextStyle(color: Colors.white, fontSize: 18),
        ),
        backgroundColor: Colors.black,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection(
              'AI Debate System',
              'Two LLMs argue opposing positions on any topic. Each model is constrained to make falsifiable claims and directly challenge the opponent.',
              Icons.psychology,
            ),
            _buildDivider(),
            _buildSection(
              'Multi-Model Architecture',
              '''The system uses different models for each side:

• **Proponent (PRO)**: Llama 3.2 - Fast, consistent reasoning
• **Opponent (CON)**: Gemma 2:2b - Creative, divergent arguments

This creates natural tension through different reasoning styles.''',
              Icons.compare_arrows,
            ),
            _buildDivider(),
            _buildMathSection(
              'Persuasiveness Score',
              'Each turn is scored based on claim quality, direct answering, and attack strength:',
              r'P = \frac{C_{claim} + C_{answer} + C_{attack}}{3} - V_{penalty}',
              '''Where:
• **C_claim** = Claim quality (0-100)
• **C_answer** = Direct answer score (0-100)
• **C_attack** = Attack strength (0-100)  
• **V_penalty** = Vagueness penalty (-30 per abstraction)''',
            ),
            _buildDivider(),
            _buildMathSection(
              'Power Bar Calculation',
              'The power bar shows cumulative persuasiveness:',
              r'R_{pro} = \frac{\sum_{i} P_{pro,i}}{\sum_{i} P_{pro,i} + \sum_{j} P_{con,j}} \times 100\%',
              'The green portion represents PRO\'s cumulative strength relative to CON.',
            ),
            _buildDivider(),
            _buildMathSection(
              'RAG Context Retrieval',
              'Relevant facts are retrieved using embedding similarity:',
              r'\text{sim}(q, d) = \frac{q \cdot d}{\|q\| \|d\|}',
              '''Cosine similarity measures how closely the query embedding (q) matches each document embedding (d). Top-k results are provided as context.''',
            ),
            _buildDivider(),
            _buildMathSection(
              'Algorithmic Scoring',
              'When using ALGO mode, scores are computed heuristically:',
              r'S = w_1 \cdot L_{arg} + w_2 \cdot K_{rel} + w_3 \cdot C_{struct}',
              '''Where:
• **L_arg** = Argument length factor
• **K_rel** = Keyword relevance to topic
• **C_struct** = Structural compliance (sections present)
• **w_i** = Tuned weights''',
            ),
            _buildDivider(),
            _buildSection(
              'Debate Constraints',
              '''Each AI must follow strict rules:

1. **ONE claim per turn** - Must be falsifiable
2. **No vague abstractions** - "Mystery/meaning/purpose" banned
3. **Direct answers required** - ≤2 sentences before arguing
4. **Attack required** - Must challenge opponent
5. **No agreement** - Finding common ground = losing

These constraints force adversarial reasoning instead of polite philosophy.''',
              Icons.gavel,
            ),
            _buildDivider(),
            _buildSection(
              'Loss Conditions',
              '''A model is penalized for:

• Unanswered questions (-30)
• Contradiction with earlier statements
• Repeated abstractions detected by RAG
• Unfalsifiable claims

The judge scores each violation and reflects it in the persuasiveness score.''',
              Icons.warning_amber,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Container(
        height: 1,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.transparent,
              Colors.grey[800]!,
              Colors.grey[800]!,
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildSection(String title, String content, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: neonGreen, size: 22),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _buildRichText(content),
      ],
    );
  }

  Widget _buildMathSection(
    String title,
    String intro,
    String formula,
    String explanation,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.functions, color: neonGreen, size: 22),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          intro,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
          decoration: BoxDecoration(
            color: Colors.grey[900],
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: neonGreen.withAlpha(50)),
          ),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Math.tex(
              formula,
              textStyle: const TextStyle(fontSize: 14, color: Colors.white),
            ),
          ),
        ),
        const SizedBox(height: 12),
        _buildRichText(explanation),
      ],
    );
  }

  Widget _buildRichText(String text) {
    // Simple markdown-like parsing for bold text
    final spans = <TextSpan>[];
    final regex = RegExp(r'\*\*(.+?)\*\*');
    int currentIndex = 0;

    for (final match in regex.allMatches(text)) {
      if (match.start > currentIndex) {
        spans.add(TextSpan(text: text.substring(currentIndex, match.start)));
      }
      spans.add(
        TextSpan(
          text: match.group(1),
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      );
      currentIndex = match.end;
    }

    if (currentIndex < text.length) {
      spans.add(TextSpan(text: text.substring(currentIndex)));
    }

    return RichText(
      text: TextSpan(
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 14,
          height: 1.6,
        ),
        children: spans,
      ),
    );
  }
}
