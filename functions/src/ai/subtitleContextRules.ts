/**
 * Server-side context rules appended to subtitle translation prompts.
 * Lives on the backend so every client (mobile, desktop, web server queue)
 * gets it without an app release. Web mirror: deepnodestudios/functions/subtitleContextRules.js.
 *
 * Origin: user feedback (Oct 2026) — "Hello?" called out while searching a
 * room was rendered as the phone greeting ("Pronto?" in Italian), and
 * participles/insults ignored the speaker's or addressee's gender.
 */
export const SUBTITLE_CONTEXT_RULES = `

Context rules (apply before choosing each line's wording):
- First read the whole input and work out who is speaking to whom, where they are and what is happening. Use neighbouring lines only to choose the right wording; never merge, move or add content between subtitle blocks.
- Interjections, greetings and short calls change meaning with the situation: translate what the line does in the scene, not its dictionary word. "Hello?" called out while searching a place or checking whether someone is there means "Is anyone there?" (Italian "C'è qualcuno?", Turkish "Kimse var mı?"), not a phone greeting; use the telephone greeting (Italian "Pronto?") only when the line is clearly spoken into a phone or radio. Treat "Hey", "Come on", "Excuse me", "Sorry", "Right", "Okay" and "Look" the same way.
- In languages with grammatical gender, make adjectives, participles, insults and forms of address agree with the real gender of the speaker and of the person being addressed. Infer it from names, pronouns, titles and earlier lines, and keep it consistent for the same character; if it truly cannot be inferred, prefer a gender-neutral wording instead of guessing.`;

/** Marker used to detect prompts that already carry these rules. */
const SUBTITLE_CONTEXT_RULES_MARKER = 'Context rules (apply before choosing';

/**
 * Only real subtitle-translation prompts get the rules; other callers of
 * translateText (term memory, editing tools) are left untouched.
 */
export function withSubtitleContextRules(systemPrompt: string): string {
    if (!systemPrompt.includes('professional subtitle translator')) {
        return systemPrompt;
    }
    if (systemPrompt.includes(SUBTITLE_CONTEXT_RULES_MARKER)) {
        return systemPrompt;
    }
    return `${systemPrompt}${SUBTITLE_CONTEXT_RULES}`;
}
