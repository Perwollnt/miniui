<col style="bg:black">
  <!-- <text style="color:yellow">{{big.title}}</text> -->
  <!-- <text style="color:white">{{big.used}} / {{big.cap}}  ({{big.pct}}%)</text> -->
  <!-- Gauge frame -->
  <box style="height:{{big.max}}%; width:100%; bg:gray;">
    <!-- bottom-up fill: spacer first, then the fill -->
    <text style="width:100%;padding:6;bg:gray">{{big.pct}}%</text>
  </box>
  <box style="height:{{big.pct}}%; width:100%; bg:green;">
  </box>
</col>