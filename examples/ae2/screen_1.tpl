<col style="padding:0; gap:0; height:100%;width:100%; bg:gray">

  <row style="gap:0">

    <!-- LEFT LIST (panel gray, text on black) -->
    <box style="width:33%; padding:1; bg:gray">
      <box style="bg:black; padding:1">
        <text style="color:white; bg:black">{{left_list}}</text>
      </box>
    </box>

    <!-- MIDDLE LIST (panel gray, text on black) -->
    <box style="width:33%; padding:1; bg:gray">
      <box style="bg:black; padding:1">
        <text style="color:white; bg:black">{{middle_list}}</text>
      </box>
    </box>

    <!-- RIGHT PANEL -->
    <box style="width:33%; padding:1; bg:gray">
      <box style="bg:black; gap:1; padding:1; height:52%">
        <!-- ENERGY -->
        <text style="color:white">Energy {{energy.used}}/{{energy.cap}} ({{energy.pct}}%)   net {{energy.net}} RF/t</text>
        <box style="height:1; padding:0; bg:lightGray">
          <box style="width:{{energy.pct}}%; height:1; bg:orange"></box>
        </box>

        <!-- ITEMS -->
        <text style="color:white">Items {{items.used}}/{{items.cap}} ({{items.pct}}%)</text>
        <box style="height:1; padding:0; bg:lightGray">
          <box style="width:{{items.pct}}%; height:1; bg:blue"></box>
        </box>

        <!-- FLUIDS -->
        <text style="color:white">Fluids {{fluids.used}}/{{fluids.cap}} ({{fluids.pct}}%)</text>
        <box style="height:1; padding:0; bg:lightGray">
          <box style="width:{{fluids.pct}}%; height:1; bg:cyan"></box>
        </box>

        <!-- SECTION SPACER -->
        <spacer style="height:1"></spacer>

        <text style="color:yellow">Crafting</text>
        <text style="color:white">Tasks {{craft.tasks}}</text>
      </box>
      <box style="height:48%;bg:lightGray; width:100%; padding:1">

      </box>
    </box>

  </row>
</col>
