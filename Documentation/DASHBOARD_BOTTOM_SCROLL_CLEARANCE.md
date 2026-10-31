# Dashboard Bottom Scroll Clearance — V3.6

The Home dashboard now adds 116 pt of trailing scroll content clearance.

Reason: the custom floating bottom navigation is intentionally overlay-like and visually tall. Without additional scroll content at the end of `HomeView`, the last row of quick-tool cards could stop partially behind the navigation bar on a physical iPhone.

The additional clearance only affects the scrollable Home dashboard content. It does not move or resize the bottom navigation bar and does not change any business logic.
