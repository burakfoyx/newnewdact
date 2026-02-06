# Design Guidelines & References

## Core Aesthetic: Liquid Glass
The application follows the **Liquid Glass** design language (iOS 26 standard), emphasizing transparency, fluid motion, and depth.

### Key Principles
1.  **Transparency & Blur**: Use heavy usage of `UltraThinText` and `ThinMaterial` to create a sense of depth.
2.  **Fluidity**: Elements should morph and flow. Animations are spring-based and responsive.
3.  **Vibrancy**: Colors should shine through glass layers. Backgrounds are dynamic.

## Official References

### Components
*   **Buttons**: [Human Interface Guidelines - Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons)
    *   Prioritize clear, tappable areas.
    *   Use context-appropriate styles (bordered, plain, filled).
    *   For this app, prefer our custom **Liquid** styled buttons for primary actions.

### Visual Styling
*   **Materials**: [Human Interface Guidelines - Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
    *   Use Materials to separate layers of content.
    *   Ensure contrast ratios remain accessible on variable backgrounds.

### Technology
*   **Adopting Liquid Glass**: [Apple Documentation](https://developer.apple.com/documentation/TechnologyOverviews/adopting-liquid-glass)
    *   Primary reference for the shader effects and material properties used in the app.
    *   Consult for best practices on performance vs. visual fidelity.
