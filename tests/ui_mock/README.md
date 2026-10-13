# Headless UI shims (TEST USE ONLY)

GNU Octave has no `uifigure` / `uigridlayout`, so the dashboard cannot be
displayed there. `tests/testGui.m` adds this folder to the path **only under
Octave**: every UI constructor returns a `MockComponent` that simply stores its
properties and callbacks, dialogs return queued answers, and the four drawing
helpers (`showImage`, `showEmptyState`, `plotHistograms`, `plotConfusion`) only
record that they were called.

This executes the real page builders and the real `AppController` logic
(navigation, enable/disable rules, step execution, invalidation, prediction,
training, export, settings) without a display. It does **not** test how the
dashboard looks or the MATLAB graphics calls inside the four drawing helpers;
under MATLAB, `tests/testGui.m` drives the real dashboard instead.
