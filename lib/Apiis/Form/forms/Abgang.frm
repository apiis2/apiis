<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Form PUBLIC "1" "form.dtd">
<Form Name="FORM_1137394436">
  <General Name="G43" StyleSheet="/etc/apiis.css" Description="Handling animal exits"/>
  <Block Name="B44" Description="Update transfer">
    <DataSource Name="DS45" Connect="no">
      <Record TableName="transfer"/>
      <Column DBName="db_animal" Name="C1" Order="0" Type="DB"/>
      <Column DBName="ext_animal" Name="C2" Order="0" Type="DB"/>
      <Column DBName="db_unit" Name="C5" Order="1" Type="DB"/>
         <Column DBName="ext_unit" Name="C9" Order="2" RelatedColumn="C5" RelatedOrder="0" Type="Related"/>
         <Column DBName="ext_id" Name="C11" Order="3" RelatedColumn="C5" RelatedOrder="1" Type="Related"/>
      <Column DBName="opening_dt" Name="C23" Order="7" Type="DB"/>
      <Column DBName="entry_dt" Name="C26" Order="8" Type="DB"/>
      <Column DBName="exit_dt" Name="C29" Order="9" Type="DB"/>
      <Column DBName="closing_dt" Name="C32" Order="10" Type="DB"/>
      <Column DBName="db_entry_action" Name="C35" Order="11" Type="DB"/>
      <Column DBName="db_exit_action" Name="C38" Order="12" Type="DB"/>
      <Column DBName="guid" Name="C41" Order="13" Type="DB"/>
    </DataSource>
      
    <!-- Titel Label -->
    <Label Name="L0" Content="Handling Animal Exits">
      <Position Column="0" Columnspan="1" Position="absolute" Row="0"/>
      <Text FontSize="24px" TextDecoration="underline"/>
    </Label>

    <!-- Animal ID -->
    <Label Name="L1" Content="Animal ID">
      <Position Column="0" Position="absolute" Row="1"/>
    </Label>
    <Field Name="F1" DSColumn="C1" FlowOrder="0" >
      <!-- db_animal -->
      <TextField Size="20"/>
      <Position Column="0" Position="absolute" Row="0"/>
      <Miscellaneous Visibility="hidden" Enabled="no"/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Field Name="F8" DSColumn="C5" >
      <!-- db_unit -->
      <TextField Override="no" Size="20"/>
      <Position Column="0" Position="absolute" Row="0"/>
      <Miscellaneous Visibility="hidden" Enabled="no"/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Field Name="F10" DSColumn="C9" FlowOrder="1" >
      <!-- ext_unit -->
      <TextField Override="no" Size="20"/>
      <Position Column="1" Position="absolute" Row="1"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Field Name="F12" DSColumn="C11" FlowOrder="2" >
      <!-- ext_id -->
      <TextField Override="no" Size="20"/>
      <Position Column="2" Position="absolute" Row="1"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Field Name="F3" DSColumn="C2" FlowOrder="0" >
      <!-- ext_animal -->
      <TextField Override="no" Size="20"/>
      <Position Column="3" Position="absolute" Row="1"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <!-- Opening stuff -->
    <!-- opening_dt  -->
    <Label Name="L22" Content="opening_dt">
      <Position Column="1" Position="absolute" Row="2"/>
    </Label>
    <Field Name="F24" DSColumn="C23" FlowOrder="5" >
      <TextField Override="no" Size="10"/>
      <Position Column="1" Position="absolute" Row="3"/>
      <Miscellaneous Enabled="no"/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <!-- entry_dt  -->
    <Label Name="L25" Content="entry_dt">
      <Position Column="2" Position="absolute" Row="2"/>
    </Label>
    <Field Name="F27" DSColumn="C26" FlowOrder="6" >
      <TextField Override="no" Size="10"/>
      <Position Column="2" Position="absolute" Row="3"/>
      <Miscellaneous Enabled="no"/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <!-- db_entry_action  -->
    <Label Name="L34" Content="db_entry_action">
      <Position Column="3" Position="absolute" Row="2"/>
    </Label>
    <Field Name="F36" DSColumn="C35" FlowOrder="9" >
      <TextField Size="15"/>
      <Position Column="3" Position="absolute" Row="3"/>
      <Miscellaneous Enabled="no"/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <!-- Closing stuff -->
    <!-- exit_dt  -->
    <Frame Name="closing_stuff_frame" Label="Exit Data" LabelPosition="top"
           LabelForeground="blue" Relief="sunken" >
    <Position Column="1" Row="4" Columnspan="3" Sticky="ew"/>
    <Format PaddingTop="20" PaddingRight="20" IPaddingTop="20" IPaddingRight="20"/>

       <Label Name="L28" Content="exit_dt">
         <Position Column="0" Position="absolute" Row="1"/>
         <Format/>
       </Label>
       <Field Name="F30" DSColumn="C29" FlowOrder="7" >
         <Calendar/>
         <Position Column="0" Position="absolute" Row="2"/>
         <Miscellaneous/>
         <Text/>
         <Color/>
         <Format/>
       </Field>
       
       <!-- db_exit_action  -->
       <Label Name="L37" Content="db_exit_action">
         <Position Column="1" Position="absolute" Row="1"/>
       </Label>
       <Field Name="F39" DSColumn="C38" FlowOrder="10" >
         <BrowseEntry Size="15"/>
         <Position Column="1" Position="absolute" Row="2"/>
         <Miscellaneous/>
         <Text/>
         <Color/>
         <Format/>
       </Field>
       
       <!-- closing_dt  -->
       <Label Name="L31" Content="closing_dt">
         <Position Column="2" Position="absolute" Row="1"/>
       </Label>
       <Field Name="F33" DSColumn="C32" FlowOrder="8" >
         <Calendar/>
         <Position Column="2" Position="absolute" Row="2"/>
         <Miscellaneous/>
         <Text/>
         <Color/>
         <Format/>
       </Field>
       <Color BackGround="pink"/>
    </Frame>

    <!-- Misc stuff  -->
    <!-- guid  -->
    <Field Name="F42" DSColumn="C41" FlowOrder="11" >
      <TextField Override="no" Size="20"/>
      <Position Column="0" Position="absolute" Row="0"/>
      <Miscellaneous Visibility="hidden" Enabled="no"/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    &NavigationButtons_Fields;
    &ActionButtons_Fields;

    <Color BackGround="#f0f0f0"/>
    <Format BorderStyle="ridge" BorderColor="#f0f0f0" MarginTop="10px"/>
  </Block>

<!--  &StatusLine2_Block;
-->
</Form>
<!-- vim: set fdl=5 foldmethod=syntax filetype=xml:-->
