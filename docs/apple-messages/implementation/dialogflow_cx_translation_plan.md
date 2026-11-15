# Translating AcousticHouseBotService.rb to Dialogflow CX

This document outlines how to translate the Ruby-based `AcousticHouseBotService` into a Dialogflow CX conversational agent.

### 1. Core Logic: State Machine vs. Flow-Based Control

*   **AcousticHouseBotService.rb**: The bot operates as a classic state machine. The user's current position in the conversation is tracked by `@bot_state` (e.g., `'AHA1'`, `'AHB2'`). The main logic in `process_state` is a large `case` statement that routes the user to the correct handler method based on their current state. State transitions are managed manually by calling `update_bot_state(new_state)` within each handler.

*   **Dialogflow CX Translation**: This state machine translates directly to **Flows** and **Pages**.
    *   **Flows**: The entire `AcousticHouseBotService.rb` could be considered a single master **Flow** in Dialogflow CX, perhaps named "Guitar Purchase Flow". If the bot were more complex, logical sections like "Onboarding", "Guitar Selection", and "Scheduling" could be broken into separate, reusable Flows.
    *   **Pages**: Each `when 'STATE_NAME'` in the `case` statement corresponds to a **Page** in Dialogflow CX. For example, the state `'AHA1'` (`handle_welcome`) would become the `Start Page` of the flow. The state `'AHA2'` (`handle_region_prompt`) would be a new page called `Region Prompt`.
    *   **State Transitions**: Instead of manually calling `update_bot_state`, you define **Routes** on each Page. A Route consists of a condition (like an intent being matched or a form parameter being filled) and a target destination (the next Page). This is a more visual and declarative way to manage the conversation path.

### 2. User Input Handling: Keywords vs. Intents

*   **AcousticHouseBotService.rb**: User input is primarily handled through exact keyword matching in the `handle_keyword_message` method. It checks the user's text against predefined `DEMO_KEYWORDS` and `FLOW_CONTROL_KEYWORDS`. This is rigid and doesn't account for variations in user phrasing.

*   **Dialogflow CX Translation**: Keywords are replaced by **Intents**.
    *   An **Intent** represents what the user *wants to do*, not just what they *typed*. You would create intents and provide a variety of **training phrases**.
    *   `FLOW_CONTROL_KEYWORDS`: The keywords `'menu'`, `'start over'`, and `'restart'` would all be training phrases for a `StartOver` intent.
    *   `DEMO_KEYWORDS`: The keywords `'list picker'`, `'guitar'`, and `'guitars'` would be training phrases for a `ShowGuitarDemo` intent.
    *   Dialogflow's Natural Language Understanding (NLU) engine then matches user input to the best intent, which is far more flexible than exact string matching.

### 3. Interactive Elements: Handlers vs. Form Parameters & Payloads

*   **AcousticHouseBotService.rb**: Interactive responses (like button clicks or list selections) are routed via the `INTERACTIVE_HANDLERS` hash. It maps a `request_id` (e.g., `'lp_guitar_0319'`) to a specific handler method.

*   **Dialogflow CX Translation**: This maps to **Form Parameters** and **Event Handlers**.
    *   **Forms**: A Page in Dialogflow CX can have a **Form**, which is used to collect information from the user. For example, the `Region Prompt` page would have a parameter called `region`. The fulfillment for that page would send the quick reply buttons.
    *   **Payloads**: When a user clicks a button like "Americas", the platform sends a payload back to Dialogflow. This payload would be configured to fill the `region` parameter with the value "Americas".
    *   **Event Handlers**: Alternatively, button clicks can trigger custom **Events**. You can create a route that transitions the user to a new page when a specific event (e.g., `selected_americas`) is received. This is useful for actions that don't just fill a parameter but cause a direct change in the conversation flow.

### 4. Conversation State: Custom Attributes vs. Session Parameters

*   **AcousticHouseBotService.rb**: The bot stores information about the conversation (like the user's name or region selection) in `@conversation.custom_attributes`. This is a simple key-value store.

*   **Dialogflow CX Translation**: This is handled by **Session Parameters**.
    *   When a form parameter is filled (e.g., `region` = "Americas"), that value is automatically stored as a session parameter.
    *   You can access these parameters throughout the conversation using `$session.params.region`. This is equivalent to reading from the `custom_attributes` hash.
    *   This is a more structured approach, as parameters are explicitly defined and managed by the platform.

### Summary of Translation

| Acoustic House Bot Concept | Dialogflow CX Equivalent |
| :--- | :--- |
| **State Machine** (`case @bot_state`) | **Flows and Pages** |
| **State** (`'AHA1'`, `'AHB2'`, etc.) | **Page** |
| **State Transition** (`update_bot_state`) | **Routes** (on a Page) |
| **Keyword Matching** (`DEMO_KEYWORDS`) | **Intents** with Training Phrases |
| **Interactive Handlers** (`INTERACTIVE_HANDLERS`) | **Form Parameters** & **Event Handlers** |
| **Custom Attributes** (`@conversation.custom_attributes`) | **Session Parameters** (`$session.params.<name>`) |
| **Handler Methods** (`handle_welcome`, etc.) | **Fulfillment** (on a Page or Route) |
| **Timeout Logic** (`conversation_timed_out?`) | **No-match Handlers** and **Event Handlers** on the Page (e.g., `sys.no-match-default`) |

By mapping these concepts, the entire conversational logic can be rebuilt in Dialogflow CX's visual, flow-based editor, leveraging its powerful NLU and state management capabilities for a more robust and scalable agent.
---

### How Dialogflow CX Connects to Chatwoot AMB Templates

A common question is how an external service like Dialogflow CX can trigger the rich, interactive Apple Messages for Business (AMB) templates that are defined and stored within Chatwoot. The connection is not automatic; it requires a custom integration layer that acts as a bridge.

#### The Integration Architecture

The core concept is to separate the "brain" of the bot (Dialogflow) from its "body" (Chatwoot).

1.  **Chatwoot as the Message Broker**: All messages from a user on AMB are first received by the Chatwoot inbox.

2.  **Webhook Forwarder**: A service (like a simplified Agent Bot or a dedicated webhook endpoint) is set up in Chatwoot. Its primary role is to receive incoming messages and forward them to the Dialogflow CX `detectIntent` API. This request includes the user's text and a unique session ID (typically the Chatwoot conversation ID).

3.  **Dialogflow CX for Logic**: Dialogflow processes the text, uses its NLU engine to match an intent, and transitions to the appropriate flow and page.

4.  **Custom Payload Fulfillment**: This is the critical step. Instead of responding with simple text, the **Fulfillment** for a Dialogflow page is configured to return a **Custom Payload**. This is a JSON object that you design to act as an instruction for Chatwoot.

5.  **Chatwoot Service Receives Payload**: The custom payload is sent back from Dialogflow to your webhook service.

6.  **Translate Payload to Action**: Your service parses the JSON payload and acts on it. It's a mapping layer. For example, if the service receives the following payload:
    ```json
    {
      "action": "send_amb_template",
      "template_name": "ah_guitar_list_picker"
    }
    ```

7.  **Trigger Chatwoot Template**: Based on this instruction, your service would then execute the internal Chatwoot logic required to send the `ah_guitar_list_picker` AMB template to the user in the correct conversation.

This architecture allows you to use Dialogflow's advanced conversational features while keeping Chatwoot as the central platform for managing all customer interactions and message templates.