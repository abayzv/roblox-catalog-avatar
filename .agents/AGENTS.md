# Roblox UI Guidelines

When creating or modifying Roblox UIs in this workspace, strictly follow the layout guidelines and patterns defined in `roblox_ui_layout_guide.md`.

Key points to remember:
- **Root Screen**: Always fill the screen (`Size = UDim2.fromScale(1, 1)`). Do not rely on fixed sizes for the root layout.
- **Split Area Layout**: Use `Scale` to divide main areas (e.g., Left/Right or Main/Side).
- **Content Scaling**: Use `UIScale` to scale down the *content* of an area rather than fixing the size of the area itself when it needs to be smaller on mobile. Ensure internal components maintain proportional design size.
- **Fixed Height Rows**: Explicitly define heights for components using `UIListLayout` to ensure consistency.
- **Stroke Clipping**: Always provide enough padding (4-6px) so that `UIStroke` does not get clipped.
- **Grid Layout**: Calculate cell sizes based on a viewport scale, avoiding double scaling.
- **Canvas Size**: Explicitly calculate scrolling canvas sizes using estimated content height to prevent cutoff at the bottom.
- **Modal Blocker (Optional)**: Modals should block inputs with `Modal = true`, and Z-Index must be carefully managed. Use only for true modal UIs (like shop/settings). Do not use blocker for HUDs or non-modal overlays.
- **ViewportFrame Preview**: Use proper structure (PreviewPanel -> Stage -> ViewportFrame -> WorldModel -> Camera) and ensure camera fit calculations are based on the model's bounding box.

Never use fixed offset sizes for main structural surfaces that should adapt to different screen dimensions.

# Architecture Guidelines

- **Avatar Preview Flow**: Always use a `ViewportFrame` clone for previewing avatars ("Try On"). 
- **DO NOT** mutate the live local character (`Players.LocalPlayer.Character`) during preview.
- **Server Application**: Only apply the final avatar choice to the live character via server request when the user confirms ("Apply"). Do not fire remotes during Try On.
- **Reset Preview**: Reset actions must clear or restore the state of the viewport clone, not the local live character.
- **UI State**: Apply and Reset buttons must read from the `PreviewState` of the items currently being previewed in the viewport.
- **Remote Payload & Validation**: The apply payload must be the final item IDs from `PreviewState`, not a diff. The server must validate the whitelist/ownership of these item IDs and not trust visual changes from the client.
