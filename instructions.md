Goal
Add a “Gemini model” selector to Settings → API Configuration so users can switch between any of the multi-modal Gemini models (e.g. gemini-2.0-flash, gemini-2.0-flash-lite, gemini-1.5-pro, gemini-1.5-flash, etc.). The picker must persist the choice, and LatexAPIService must call the model that was selected.

Below is the shortest path from design to a working feature.

1 ∙ Plan the data you need
| Item | Purpose | Where to store |
|------|---------|---------------|
| Raw model ID string (e.g. `gemini-2.0-flash`) | Sent in the request path `models/{model}:generateContent` :contentReference[oaicite:0]{index=0} | `UserDefaults` key `geminiModel` |
| Friendly display name (e.g. *Gemini 2.0 Flash (default)*) | Shown in the Settings picker | Local enum or array |

2 ∙ Update the settings model
SettingsManager.swift

Add
@Published var selectedModel: String
Initialise it from UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.0-flash"

Persist in the didSet block exactly as the other @Published properties do.

3 ∙ Expose the list of models
Create a small helper (enum or static [Model]) in Config.swift:

struct GeminiModel: Identifiable {
    let id: String      // raw id used in the URL
    let label: String   // shown to the user
    let note: String?   // optional footnote (speed / cost)
}

let availableGeminiModels: [GeminiModel] = [
    .init(id: "gemini-2.0-flash",      label: "Gemini 2.0 Flash (fast-accurate)", note: nil),
    .init(id: "gemini-2.0-flash-lite", label: "Gemini 2.0 Flash-Lite (low cost)", note: nil),
    .init(id: "gemini-1.5-pro",        label: "Gemini 1.5 Pro (large context)",  note: nil),
    .init(id: "gemini-1.5-flash",      label: "Gemini 1.5 Flash (balanced)",     note: nil)
    // add others when needed
]
(Using the “latest-stable” IDs recommended in the official model list) 
Google AI for Developers

4 ∙ Extend the Settings UI
SettingsView.swift

Inside the existing “API Configuration” section, add:

VStack(alignment: .leading, spacing: 8) {
    LabeledContent("Gemini Model:") {
        Picker("", selection: $settings.selectedModel) {
            ForEach(availableGeminiModels) { model in
                Text(model.label).tag(model.id)
            }
        }
        .pickerStyle(.menu)    // simple, compact
        .frame(width: 330)
    }
    Text("Choose speed / cost trade-offs for LaTeX extraction")
        .font(.caption).foregroundStyle(.secondary)
}
The design remains minimal (single pop-up menu, no extra window real estate).

No validation is needed – values come from the fixed list.

5 ∙ Feed the choice into network calls
LatexAPIService.swift

Add a model parameter to extractLatex(…) or read it directly inside with

let model = UserDefaults.standard.string(forKey: "geminiModel") ?? "gemini-2.0-flash"
Build the URL dynamically

let base = "https://generativelanguage.googleapis.com/v1beta/models"
guard let url = URL(string: "\(base)/\(model):generateContent?key=\(apiKey)") else { … }
Remove the hard-coded Config.geminiEndpoint (or keep it as a helper that now takes model).

6 ∙ Backward compatibility
On first launch after the update, selectedModel falls back to the previous default (gemini-2.0-flash) so existing users see no change until they pick another model.

7 ∙ Polish the UX
Minimalist feel: one picker, single-line helper text, identical typography to existing fields.

Discoverability: keep it under “API Configuration” so it’s noticed while entering the key.

Safety: if Google retires a model, the API returns 404 – your existing error handling will surface the message. Optionally map that to a user-friendly alert (“Model not available; try another.”).

8 ∙ Test
Run the app → Settings → choose Gemini 1.5 Pro.

Extract LaTeX from any image; inspect logs to verify the request path includes models/gemini-1.5-pro.

Repeat with Flash-Lite and ensure noticeably faster/cheaper responses.