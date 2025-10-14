<col style="padding:0; gap:0; height:100%;width:100%; bg:gray">

  <row style="gap:0">

    <!-- LEFT LIST (panel gray, text on black) -->
    <!-- <click on="inc"   style="height:48%">{{import "partials/card.html"}}</click> -->
    <click on="inc" style="width:33%;padding:1; bg:gray">
      <box style="bg:black; padding:1">
        <text style="color:white; bg:black">{{left_list}}</text>
      </box>
    </click>

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
      <spacer></spacer>
      <box style="height:3;bg:black;width:100%; padding:1">{{input}}</box>
      <box style="height:48%;bg:lightGray; width:100%; padding:1;">
        <row>
          <click on="ltr_q" style="color:black; width:3;height:3; bg:gray;"><text style="padding:1">Q</text></click>
          <spacer></spacer>
          <click on="ltr_w" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">W</text></click>
          <spacer></spacer>
          <click on="ltr_e" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">E</text></click>
          <spacer></spacer>
          <click on="ltr_r" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">R</text></click>
          <spacer></spacer>
          <click on="ltr_t" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">T</text></click>
          <spacer></spacer>
          <click on="ltr_u" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">U</text></click>
          <spacer></spacer>
          <click on="ltr_i" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">I</text></click>
          <spacer></spacer>
          <click on="ltr_o" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">O</text></click>
          <spacer></spacer>
          <click on="ltr_p" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">P</text></click>
          <spacer></spacer>
          <click on="ltr_bps" style="color:black; width:4;height:3; bg:gray"><text style="padding:1"><-</text></click>
        </row>

        <row>
          <click on="ltr_a" style="color:black; width:3;height:3; bg:gray;"><text style="padding:1">A</text></click>
          <spacer></spacer>
          <click on="ltr_s" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">S</text></click>
          <spacer></spacer>
          <click on="ltr_d" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">D</text></click>
          <spacer></spacer>
          <click on="ltr_f" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">F</text></click>
          <spacer></spacer>
          <click on="ltr_g" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">G</text></click>
          <spacer></spacer>
          <click on="ltr_h" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">H</text></click>
          <spacer></spacer>
          <click on="ltr_j" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">J</text></click>
          <spacer></spacer>
          <click on="ltr_k" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">K</text></click>
          <spacer></spacer>
          <click on="ltr_l" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">L</text></click>
        </row>
        <row>
          <click on="ltr_y" style="color:black; width:3;height:3; bg:gray;"><text style="padding:1">Y</text></click>
          <spacer></spacer>
          <click on="ltr_x" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">X</text></click>
          <spacer></spacer>
          <click on="ltr_c" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">C</text></click>
          <spacer></spacer>
          <click on="ltr_v" style="color:black; width:3;height:3; bg:gray"><text style="padding:1">V</text></click>
          <spacer></spacer>
          <click on="ltr_b"  style="color:black; width:3;height:3; bg:gray"><text style="padding:1">B</text></click>
          <spacer></spacer>
          <click on="ltr_n"  style="color:black; width:3;height:3; bg:gray"><text style="padding:1">N</text></click>
          <spacer></spacer>
          <click on="ltr_m"  style="color:black; width:3;height:3; bg:gray"><text style="padding:1">M</text></click>
          <spacer></spacer>
          <click on="ltr_spc"  style="color:black; width:3;height:3; bg:gray"><text style="padding:1">_</text></click>
          <spacer></spacer>
          <click on="ltr_mns"  style="color:black; width:3;height:3; bg:gray"><text style="padding:1">-</text></click>
        </row>
        

      </box>
    </box>

  </row>
</col>
