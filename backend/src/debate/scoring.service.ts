import { Injectable } from '@nestjs/common';
import * as natural from 'natural';

@Injectable()
export class ScoringService {
    private tokenizer: natural.WordTokenizer;
    private sentimentAnalyzer: natural.SentimentAnalyzer;

    constructor() {
        this.tokenizer = new natural.WordTokenizer();
        // Use PorterStemmer and AFINN vocabulary for sentiment
        this.sentimentAnalyzer = new natural.SentimentAnalyzer('English', natural.PorterStemmer, 'afinn');
    }

    calculateScore(text: string, topic: string): any {
        const tokens = this.tokenizer.tokenize(text);
        if (!tokens || tokens.length === 0) {
            return {
                persuasiveness: 0,
                rebuttal_score: 0,
                question_score: 0,
                key_point: "No content analyzed"
            };
        }

        // 1. Lexical Diversity (Unique words / Total words)
        // High diversity suggests complex vocabulary/intelligence
        const uniqueTokens = new Set(tokens.map(t => t.toLowerCase()));
        const diversity = uniqueTokens.size / tokens.length;
        const diversityScore = Math.min(diversity * 100 * 1.5, 100); // Scale up a bit

        // 2. Sentiment Analysis
        // We take absolute value because strong emotion (pos or neg) moves debates
        const sentiment = this.sentimentAnalyzer.getSentiment(tokens);
        const sentimentMagnitude = Math.min(Math.abs(sentiment) * 20, 100); // Normalize roughly 0-5 scale to 0-100

        // 3. Logical Density
        // Look for connectors: therefore, thus, because, consequently, hence
        const logicalConnectors = /\b(therefore|thus|because|consequently|hence|implies|indicates|proven)\b/gi;
        const logicMatches = (text.match(logicalConnectors) || []).length;
        // Cap at 5 connectors for max score
        const logicScore = Math.min((logicMatches / 5) * 100, 100);

        // 4. Weighted Final Score
        // Logic weighs heavy (40%), Diversity (30%), Sentiment (30%)
        let finalScore = (logicScore * 0.4) + (diversityScore * 0.3) + (sentimentMagnitude * 0.3);

        // Ensure score stays within bounds and adds some variance based on topic relevance (simple keyword check)
        const topicKeywords = topic.split(' ').filter(w => w.length > 3);
        const relevanceMatches = tokens.filter(t => topicKeywords.includes(t.toLowerCase())).length;
        if (relevanceMatches > 0) finalScore += 5; // Bonus for staying on topic

        finalScore = Math.min(Math.max(finalScore, 0), 100);

        // 5. Dynamic Tagging
        let tag = "Standard Argument";
        if (logicScore > 70) tag = "Highly Logical";
        else if (sentimentMagnitude > 60) tag = "Emotional Appeal";
        else if (diversityScore > 80) tag = "Complex Vocabulary";
        else if (text.length > 200) tag = "Detailed Response";
        else if (finalScore > 80) tag = "Strong Point";
        else tag = "Concise Point";

        return {
            persuasiveness: Math.round(finalScore),
            rebuttal_score: Math.round(logicScore), // Use logic score as proxy for strong rebuttal
            question_score: text.includes('?') ? 80 : 0,
            key_point: tag
        };
    }
}
