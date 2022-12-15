<?xml version="1.0" encoding="ISO-8859-1"?>
<!DOCTYPE Form PUBLIC "1" "form.dtd">
<Form Name="FORM_1137394436">
  <General Name="G474" StyleSheet="/etc/apiis.css" Description="Ablammung"/>

  <Block Name="TitleBlock" Description="Display heading">
    <DataSource Name="DS_title">
        <none/>
    </DataSource>
    <Label Name="L_title" Content="Ablammung" Relief="flat">
      <Position Column="0" Columnspan="6" Position="absolute" Row="0"
          Sticky="ew" Anchor="center"/>
      <Text FontSize="24px" TextDecoration="underline"/>
      <Color/>
      <Format PaddingTop="10"/>
    </Label>
  </Block>

  <Block Name="Muttertier" Description="Mutterschaf in entry_transfer">
    <DataSource Name="DS476">
      <!-- Some kind of dummy DS. We don't want updates here so we fill the
      Fields with sql statements on Field level, depending on other field
      values. -->
      <Sql Statement="SELECT 1"/>
      <Column    Name="Col0" DBName="db_animal"  TableName="transfer" Order="0" Type="DB">
          <IdSet Name="idset_col0_1" SetName="Herdbuchnr"/>
          <IdSet Name="idset_col0_2" SetName="Lebendnr"/>
          <IdSet Name="idset_col0_3" SetName="Lammnr"/>
      </Column>
         <Column Name="Col1" DBName="ext_unit"   TableName="unit"     Order="1" RelatedColumn="Col0" RelatedOrder="0" Type="Related"/>
         <Column Name="Col2" DBName="ext_id"     TableName="unit"     Order="2" RelatedColumn="Col0" RelatedOrder="1" Type="Related"/>
         <Column Name="Col3" DBName="ext_animal" TableName="transfer" Order="3" RelatedColumn="Col0" RelatedOrder="2" Type="Related"/>
    </DataSource>

    <Frame Name="frame_animal_id" Label="Mutterschaf" LabelForeground="blue" Relief="raised">
      <Position Column="0" Row="1" Columnspan="8"/>
      <Format PaddingTop="10" PaddingRight="10" IPaddingTop="20" IPaddingRight="20"/>
      
      <!-- ext_unit -->
      <Label Name="L443" Content="Nummernkreis">
        <Position Column="0" Position="absolute" Row="0" Sticky="ew" Anchor="center"/>
      </Label>
      <Field Name="F_ext_unit" DSColumn="Col1" FlowOrder="0" >
        <DataSource Name="DataSource_ext_unit">
          <Sql Statement="
              SELECT a.ext_unit FROM unit a
              INNER JOIN entry_transfer b ON a.db_unit=b.db_unit
              INNER JOIN litter c ON b.db_animal=c.db_animal
              WHERE ext_id = ? OR (ext_id IS NOT NULL AND ? IS NULL)
              GROUP BY a.ext_unit
              ORDER BY ext_unit
              "/>
          <Parameter Name="P_ext_unit_1" Key="placeholder" Value="F_ext_id"/>
          <Parameter Name="P_ext_unit_2" Key="placeholder" Value="F_ext_id"/>
        </DataSource>
        <BrowseEntry Size="18"/>
        <Position Column="0" Position="absolute" Row="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
        <Event Name="Restore_choices_ext_id_ext_anim" Type="OnSelect" Module="HandleDS" Action="get_choices">
           <Parameter Name="P_ext_unit_Ev1" Key="fieldname" Value="F_ext_id"/>
           <Parameter Name="P_ext_unit_Ev2" Key="fieldname" Value="F_ext_anim"/>
        </Event>
      </Field>

      <!-- ext_id -->
      <Label Name="L444" Content="Betrieb">
        <Position Column="1" Position="absolute" Row="0" Sticky="ew" Anchor="center"/>
      </Label>
      <Field Name="F_ext_id" DSColumn="Col2" FlowOrder="1" >
        <DataSource Name="DataSource_ext_id">
            <Sql Statement="
              SELECT a.ext_id FROM unit a
              INNER JOIN entry_transfer b ON a.db_unit=b.db_unit
              INNER JOIN litter c ON b.db_animal=c.db_animal
              WHERE ext_unit = ? OR (ext_unit IS NOT NULL AND ? IS NULL)
              GROUP BY a.ext_id
              ORDER BY ext_id
              "/>
          <Parameter Name="P_ext_id_1" Key="placeholder" Value="F_ext_unit"/>
          <Parameter Name="P_ext_id_2" Key="placeholder" Value="F_ext_unit"/>
        </DataSource>
        <BrowseEntry Size="18"/>
        <Position Column="1" Position="absolute" Row="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
        <Event Name="Restore_choices_ext_unit_ext_anim" Type="OnSelect" Module="HandleDS" Action="get_choices">
           <Parameter Name="P_ext_id_Ev1" Key="fieldname" Value="F_ext_unit"/>
           <Parameter Name="P_ext_id_Ev2" Key="fieldname" Value="F_ext_anim"/>
        </Event>
      </Field>

      <!-- ext_animal -->
      <Label Name="L445" Content="Tier">
        <Position Column="2" Position="absolute" Row="0" Sticky="ew" Anchor="center"/>
      </Label>
      <Field Name="F_ext_anim" DSColumn="Col3" FlowOrder="2" >
        <DataSource Name="DataSource_F_ext_anim">
          <Sql Statement="
              SELECT a.ext_animal FROM entry_transfer a
              INNER JOIN litter b ON a.db_animal=b.db_animal
              WHERE a.db_unit =
              (SELECT db_unit FROM unit WHERE ext_unit = ? AND ext_id = ?)
              GROUP BY a.ext_animal
              ORDER BY a.ext_animal
              "/>
          <Parameter Name="P_ext_anim_1" Key="placeholder" Value="F_ext_unit"/>
          <Parameter Name="P_ext_anim_2" Key="placeholder" Value="F_ext_id"/>
        </DataSource>
        <BrowseEntry Size="18"/>
        <Position Column="2" Position="absolute" Row="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
        <Event Name="Restore_choices_ext_unit_ext_id" Type="OnSelect" Module="HandleDS" Action="get_choices">
           <Parameter Name="P_ext_anim_Ev1" Key="fieldname" Value="F_ext_unit"/>
           <Parameter Name="P_ext_anim_Ev2" Key="fieldname" Value="F_ext_id"/>
        </Event>
        <Event Name="Notify_F_db_animal" Type="OnSelect" Module="HandleDS" Action="get_field_data">
           <Parameter Name="P_ext_anim_Ev3" Key="fieldname" Value="F_db_animal"/>
        </Event>
        <Event Name="Get_choices_db_sire" Type="OnSelect" Module="HandleDS" Action="get_choices">
           <Parameter Name="P_ext_anima_Ev4" Key="fieldname" Value="F_db_sire"/>
        </Event>
        <Event Name="Notify_F_parity" Type="OnSelect" Module="HandleDS" Action="get_field_data">
           <Parameter Name="P_ext_anima_Ev5" Key="fieldname" Value="F_parity"/>
        </Event>
      </Field>

      <!-- dummy label to move button to the right -->
      <Label Name="L446" Content="" Relief="flat">
        <Position Column="3" Position="absolute" Row="1" Sticky="ew" Anchor="center"/>
        <Format PaddingRight="15"/>
      </Label>

      <!-- Button Field for CallForm -->
      <Field Description="Call another Form" Name="CallForm_Field_0">
        <Button ButtonLabel="Abgangsmeldung" Command="do_runevents"/>
        <Position Column="4" Row="1" Sticky="ew" Anchor="e"/>
        <Text/>
        <Color BackGround="green"/>
        <Format PaddingRight="10" IPaddingRight="20"/>
        <Event Name="Event_callform" Type="CallForm" Module="CallForm" Action="callform" >
           <Parameter Name="P_cf1" Key="formname" Value="Abgang.frm"/>
           <Parameter Name="P_cf2" Key="master_sourcefield" Value="F_ext_unit"/>
           <Parameter Name="P_cf3" Key="master_sourcefield" Value="F_ext_id"/>
           <Parameter Name="P_cf4" Key="master_sourcefield" Value="F_ext_anim"/>
           <Parameter Name="P_cf5" Key="client_targetfield" Value="F10"/>
           <Parameter Name="P_cf6" Key="client_targetfield" Value="F12"/>
           <Parameter Name="P_cf7" Key="client_targetfield" Value="F3"/>
           <Parameter Name="P_cf8" Key="initial_query"      Value="1"/>
        </Event>
      </Field>
      <!-- &NavigationButtons_Fields; -->
    </Frame>
    <Color BackGround="#f0f0f0"/>
    <Format BorderStyle="ridge" BorderColor="#f0f0f0" MarginTop="10px"/>
  </Block>

  <!-- Litter block -->
  <Block Name="B_litter" Description="Wurfmeldung in litter">
    <DataSource Name="DS_litter">
      <Record TableName="litter"/>
      <Column Name="Col4"  DBName="db_animal"     Order="0" Type="DB" TableName="litter"/>
      <Column Name="Col5"  DBName="db_sire"       Order="1" Type="DB"/>
      <Column Name="Col6"  DBName="parity"        Order="2" Type="DB"/>
      <Column Name="Col7"  DBName="delivery_dt"   Order="3" Type="DB"/>
      <Column Name="Col8"  DBName="male_born_no"  Order="4" Type="DB"/>
      <Column Name="Col9"  DBName="still_born_no" Order="5" Type="DB"/>
      <Column Name="Col10" DBName="mumien_no"     Order="6" Type="DB"/>
      <Column Name="Col11" DBName="born_alive_no" Order="7" Type="DB"/>
      <Column Name="Col12" DBName="notch_start"   Order="8" Type="DB"/>
      <Column Name="Col13" DBName="weaning_dt"    Order="9" Type="DB"/>
      <Column Name="Col14" DBName="weaned_no"     Order="10" Type="DB"/>
      <Column Name="Col15" DBName="comment"       Order="11" Type="DB"/>
    </DataSource>

    <!-- db_animal -->
      <Field Name="F_db_animal" DSColumn="Col4" InternalData="yes" >
        <DataSource Name="DataSource_db_anim">
          <Sql Statement="
              SELECT db_animal FROM entry_transfer
              WHERE ext_animal = ?
              AND   db_unit    =
                 (select db_unit from unit where ext_unit = ? and ext_id = ?)
              "/>
          <Parameter Name="P_db_anim_1" Key="placeholder" Value="F_ext_anim"/>
          <Parameter Name="P_db_anim_2" Key="placeholder" Value="F_ext_unit"/>
          <Parameter Name="P_db_anim_3" Key="placeholder" Value="F_ext_id"/>
        </DataSource>
        <TextField Override="no" Size="20"/>
        <Position Column="0" Position="absolute" Row="2"/>
        <Miscellaneous Visibility="hidden" Enabled="no"/>
        <Text/>
        <Color DisabledBackGround="pink" DisabledForeGround="blue"/>
        <Format/>
      </Field>

    <!-- Frame Start -->
    <Frame Name="F_Deckbock" Label="Deckbock" LabelForeground="blue" Relief="raised">
      <Position Column="0" Row="4" Columnspan="3" Sticky="ew"/>
      <Format PaddingTop="10" PaddingRight="10" IPaddingTop="20" IPaddingRight="20"/>

      <Field Name="F_db_sire" DSColumn="Col5" FlowOrder="3"
          Description="Deckbock (db_sire)" InternalData="yes" >
        <DataSource Name="DS_F_db_sire">
          <Sql Statement="
              SELECT
                 s.db_sire,
                 u.ext_unit ||' '|| u.ext_id ||' '|| t.ext_animal ||' ('|| s.service_dt ||')'
              FROM service s, unit u, transfer t
              WHERE
                 s.db_animal = ? AND
                 s.db_sire = t.db_animal AND
                 t.db_unit = u.db_unit
              ORDER by s.service_dt DESC, u.ext_unit ASC
              "/>
          <Parameter Name="Parameter_1" Key="placeholder" Value="F_db_animal"/>
        </DataSource>
        <BrowseEntry Size="45"/>
        <Position Column="1" Row="4" Columnspan="2"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>
    </Frame>
    <!-- Frame End -->

    <!-- Frame Start -->
    <Frame Name="F_wurfdaten" Label="Wurfdaten" LabelForeground="blue" Relief="raised">
      <Position Column="0" Row="5" Columnspan="3" Sticky="ew"/>
      <Format PaddingTop="10" PaddingRight="10" IPaddingTop="20" IPaddingRight="20"/>

      <!-- delivery_dt -->
      <Label Name="L_delivery_dt" Content="Wurfdatum">
        <Position Column="0" Row="0" Anchor="center"/>
      </Label>

      <Field Name="F_delivery_dt" DSColumn="Col7" FlowOrder="5" >
        <Calendar/>
        <Position Column="0" Row="1" Sticky="ew" Anchor="center"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>

      <!-- parity -->
      <Label Name="L_parity" Content="Wurfnummer">
        <Position Column="1" Row="0" Anchor="center"/>
      </Label>

      <Field Name="F_parity" DSColumn="Col6" FlowOrder="4" >
        <DataSource Name="DS_F_parity">
          <Sql Statement="SELECT MAX(parity)+1 FROM litter WHERE db_animal = ?"/>
          <Parameter Name="P_parity_1" Key="placeholder" Value="F_db_animal"/>
        </DataSource>
        <TextField Size="3"/>
        <Position Column="1" Row="1" Sticky="ew" Anchor="center"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>

      <!-- notch_start -->
      <Label Name="L_notch_start" Content="Ohrmarkennr. ab:">
        <Position Column="2" Row="0" Anchor="center"/>
      </Label>

      <Field Name="F_notch_start" DSColumn="Col12" FlowOrder="5" >
        <TextField Size="3"/>
        <Position Column="2" Row="1" Sticky="ew" Anchor="center"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>
    </Frame>
    <!-- Frame End -->


    <!-- Frame Start -->
    <Frame Name="F_born_no" Label="Anzahl Lämmer bei Geburt" LabelForeground="blue" Relief="raised">
      <Position Column="0" Row="6" Columnspan="3" Sticky="ew"/>
      <Format PaddingTop="10" PaddingRight="10" IPaddingTop="20" IPaddingRight="20"/>

      <!-- born_alive_no -->
      <Label Name="L_born_alive_no" Content="lebend">
        <Position Column="0" Position="absolute" Row="0" Sticky="w" Anchor="center"/>
      </Label>
  
      <Field Name="F_born_alive_no" DSColumn="Col11" FlowOrder="6" >
        <TextField Size="2"/>
        <Position Column="0" Position="absolute" Row="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>

      <!-- male_born_no -->
      <Label Name="L_male_born_no" Content="männlich">
        <Position Column="1" Row="0" Sticky="w" Anchor="center"/>
      </Label>
  
      <Field Name="F_male_born_no" DSColumn="Col8" FlowOrder="6" >
        <TextField Size="2"/>
        <Position Column="1" Row="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>

      <!-- still_born_no -->
      <Label Name="L_still_born_no" Content="tot">
        <Position Column="2" Position="absolute" Row="0" Sticky="w" Anchor="center"/>
      </Label>
  
      <Field Name="F_still_born_no" DSColumn="Col9" FlowOrder="7" >
        <TextField Size="2"/>
        <Position Column="2" Row="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>

      <!-- mumien_no -->
      <Label Name="L_mumien_no" Content="Mumien">
        <Position Column="3" Position="absolute" Row="0" Sticky="w" Anchor="center"/>
      </Label>
  
      <Field Name="F_mumien_no" DSColumn="Col10" FlowOrder="8" >
        <TextField Size="2"/>
        <Position Column="3" Row="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>

    </Frame>
    <!-- Frame End -->

    <!-- comment -->
    <Frame Name="F_comments" Label="Bemerkungen" LabelForeground="blue" Relief="raised">
      <Position Column="0" Row="7" Columnspan="6" Sticky="nsew"/>
      <Format PaddingTop="10" PaddingRight="10" IPaddingTop="20" IPaddingRight="20"/>

      <Field Name="F_comment" DSColumn="Col15" FlowOrder="10" >
        <TextBlock />
        <Position Column="0" Row="0" Width="100" Height="5" Sticky="ew"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="pink"/>
        <Format/>
      </Field>
    </Frame>

    &ActionButtons_Fields;
  </Block>
  &DumpButton_Block;
  &StatusLine2_Block;
</Form>

<!-- vim: set fdl=5 foldmethod=syntax filetype=xml nowrap:-->
