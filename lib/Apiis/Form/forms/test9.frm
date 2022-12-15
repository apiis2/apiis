<?xml version="1.0" encoding="UTF-8"?>
<!--DOCTYPE Form SYSTEM "form.dtd"-->
<Form Name="Form_0">
  <General
    Description="Master/Detail Blocks in table animal" Name="General_0"/>

  <Block Description="Master block" Name="Masterblock">
    <DataSource Name="DataSource_0">
      <Record TableName="animal"/>
      <Column DBName="db_animal" Name="Column_0" Order="0" Type="DB"/>
      <Column DBName="ext_unit" Name="Column_1" Order="1" TableName="unit"
        RelatedColumn="Column_0" RelatedOrder="0" Type="Related"/>
      <Column DBName="ext_id" Name="Column_2" Order="2" TableName="unit"
        RelatedColumn="Column_0" RelatedOrder="1" Type="Related"/>
      <Column DBName="ext_animal" Name="Column_3" Order="3" TableName="transfer"
        RelatedColumn="Column_0" RelatedOrder="2" Type="Related"/>
      <Column DBName="name" Name="Column_4" Order="4" Type="DB"/>
      <Column DBName="db_sex" Name="Column_5" Order="5" Type="DB"/>
      <Column DBName="db_breed" Name="Column_51" Order="6" Type="DB"/>
    </DataSource>
    <Position Column="0" Row="0"/>

    <Frame Name="Masterblock_frame" Label="Dam"
           LabelForeground="blue" Relief="raised">
    <Position Column="0" Row="0" Columnspan="8"/>
    <Format PaddingTop="10" PaddingRight="10" IPaddingTop="20" IPaddingRight="20"/>

    <Label Content="Internal Animal ID" Name="Label_0">
      <Position Column="0" Position="absolute" Row="1"/>
    </Label>
    <Label Content="External Unit" Name="Label_1">
      <Position Column="0" Position="absolute" Row="2"/>
    </Label>
    <Label Content="External ID" Name="Label_2">
      <Position Column="2" Position="absolute" Row="2"/>
    </Label>
    <Label Content="External Animal ID" Name="Label_3">
      <Position Column="4" Position="absolute" Row="2"/>
    </Label>
    <Label Content="Name" Name="Label_4">
      <Position Column="6" Row="2"/>
    </Label>
    <Label Content="Sex" Name="Label_5">
      <Position Column="0" Row="3"/>
    </Label>
    <Label Content="Breed" Name="Label_51">
      <Position Column="2" Row="3"/>
    </Label>
    <Field DSColumn="Column_0" Description="Internal Animal ID"
      FlowOrder="0" Name="Field_0">
      <TextField Override="no" Password="no" Size="10"/>
      <Position Column="1" Position="absolute" Row="1"/>
      <Miscellaneous Visibility="visible" Enabled="no"/>
      <Text/>
      <Color DisabledBackGround="pink" DisabledForeGround="blue"/>
      <Format/>
    </Field>
    <Field DSColumn="Column_1"
      Description="External unit name" FlowOrder="1" Name="Field_1">
      <DataSource Name="DataSource_Field_1">
        <Sql Statement="SELECT ext_unit FROM unit
            WHERE ext_id = ? OR (ext_id IS NOT NULL AND ? IS NULL)
            ORDER BY ext_unit"/>
        <Parameter Name="Parameter_1" Key="placeholder" Value="Field_2"/>
        <Parameter Name="Parameter_2" Key="placeholder" Value="Field_2"/>
      </DataSource>
      <BrowseEntry Size="13"/>
      <Position Column="1" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="magenta"/>
      <Format/>
    </Field>
    <Field DSColumn="Column_2" Description="External ID" FlowOrder="2" Name="Field_2">
      <DataSource Name="DataSource_Field_2">
        <Sql Statement="
            SELECT ext_id FROM unit
            WHERE ext_unit = ? OR (ext_unit IS NOT NULL AND ? IS NULL)
            ORDER BY ext_id"/>
        <Parameter Name="Parameter_4" Key="placeholder" Value="Field_1"/>
        <Parameter Name="Parameter_5" Key="placeholder" Value="Field_1"/>
      </DataSource>
      <BrowseEntry Size="13"/>
      <Position Column="3" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="magenta"/>
      <Format/>
    </Field>
    <Field DSColumn="Column_3" Description="External Animal" FlowOrder="3" Name="Field_3">
      <TextField Override="no" Password="no" Size="10"/>
      <Position Column="5" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="magenta"/>
      <Format/>
    </Field>
    <Field DSColumn="Column_4" Description="Name" FlowOrder="4" Name="Field_4">
      <TextField Size="10" Default=""/>
      <Position Column="7" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="magenta"/>
      <Format/>
    </Field>
    <Field DSColumn="Column_5" Description="Sex" FlowOrder="5" Name="Field_5">
    <DataSource Name="DataSource_Field_5">
      <Sql Statement="select ext_code, long_name from codes where class='SEX' order by long_name"/>
    </DataSource>
      <BrowseEntry Size="5"/>
      <Position Column="1" Row="3"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="magenta"/>
      <Format/>
    </Field>
    <Field DSColumn="Column_51" Description="Breed" FlowOrder="5" Name="Field_51">
      <BrowseEntry Size="5"/>
      <Position Column="3" Row="3"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="magenta"/>
      <Format/>
    </Field>
    <Color BackGround="lightyellow"/>
    </Frame>

    <!-- Use defaults for navigation buttons and action buttons -->
    &NavigationButtons_Fields;
    &ActionButtons_Fields;
  </Block>

  <Block Description="Detail block" Name="Detailblock">
    <MasterDetail MasterBlock="Masterblock" MasterColumn="Column_0" DetailColumn="Column_6"/>
    <DataSource Name="DataSource_1">
      <Record TableName="animal"/>
      <Column DBName="db_dam" Name="Column_6" Order="6" Type="DB"/>
      <Column DBName="db_animal" Name="Column_7" Order="7" Type="DB"/>
      <Column DBName="ext_unit" Name="Column_8" Order="8"
        RelatedColumn="Column_7" RelatedOrder="0" Type="Related"/>
      <Column DBName="ext_id" Name="Column_9" Order="9"
        RelatedColumn="Column_7" RelatedOrder="1" Type="Related"/>
      <Column DBName="ext_animal" Name="Column_10" Order="10"
        RelatedColumn="Column_7" RelatedOrder="2" Type="Related"/>
      <Column DBName="db_sex" Name="Column_11" Order="11" Type="DB"/>
      <Column DBName="birth_dt" Name="Column_12" Order="12" Type="DB"/>
    </DataSource>
    <Frame Name="Detailblock_frame" Label="Progeny" LabelPosition="bottom"
           LabelForeground="blue" Relief="raised" >
    <Position Column="1" Row="4" Columnspan="4"/>
    <Format PaddingTop="10" PaddingRight="10" IPaddingTop="20" IPaddingRight="20"/>
    <Tabular Name="Tabular_0" Rows="18" MaxRows="25" FixedRows="1" ScrollBars="e">
      <Position Column="1" Row="4" Columnspan="4"/>
      <Label Content="Dam (int)" Name="Label_6">
        <Position Column="0" Row="0"/>
      </Label>
      <Label Content="Animal (int)" Name="Label_7">
        <Position Column="1" Row="0"/>
      </Label>
      <Label Content="ext. Unit" Name="Label_8">
        <Position Column="2" Row="0"/>
      </Label>
      <Label Content="ext. ID" Name="Label_9">
        <Position Column="3" Row="0"/>
      </Label>
      <Label Content="ext. Animal" Name="Label_10">
        <Position Column="4" Row="0"/>
      </Label>
      <Label Content="Sex" Name="Label_11">
        <Position Column="5" Row="0"/>
      </Label>
      <Label Content="Birthdate" Name="Label_12">
        <Position Column="6" Row="0"/>
      </Label>

      <Field DSColumn="Column_6" Description="Internal Dam ID"
        FlowOrder="4" Name="Field_6">
        <TextField Override="no" Password="no" Size="12"/>
        <Position Column="0" Row="1" Repeat="1"/>
        <Miscellaneous Visibility="visible" Enabled="no"/>
        <Text/>
        <Color DisabledBackGround="pink" DisabledForeGround="blue"/>
        <Format/>
      </Field>
      <Field DSColumn="Column_7" Description="Internal Animal ID"
        FlowOrder="4" Name="Field_7">
        <TextField Override="no" Password="no" Size="12"/>
        <Position Column="1" Row="1" Repeat="1"/>
        <Miscellaneous Visibility="visible" Enabled="no"/>
        <Text/>
        <Color DisabledBackGround="pink"/>
        <Format/>
      </Field>
      <Field DSColumn="Column_8"
        Description="External unit name" FlowOrder="5" Name="Field_8">
        <TextField Override="no" Password="no" Size="15"/>
        <Position Column="2" Row="1" Repeat="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="lightblue"/>
        <Format/>
      </Field>
      <Field DSColumn="Column_9" Description="External unit ID" FlowOrder="6" Name="Field_9">
        <TextField Override="no" Password="no" Size="15"/>
        <Position Column="3" Row="1" Repeat="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="lightblue"/>
        <Format/>
      </Field>
      <Field DSColumn="Column_10" Description="External Animal ID" FlowOrder="7" Name="Field_10">
        <TextField Override="no" Password="no" Size="15"/>
        <Position Column="4" Row="1" Repeat="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="lightblue"/>
        <Format/>
      </Field>
      <Field DSColumn="Column_11" Description="Sex" FlowOrder="8" Name="Field_11">
        <BrowseEntry Size="5"/>
        <Position Column="5" Row="1" Repeat="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="lightblue"/>
        <Format/>
      </Field>
      <Field DSColumn="Column_12" Description="Birth date" FlowOrder="9" Name="Field_12">
        <TextField Size="10"/>
        <Position Column="6" Row="1" Repeat="1"/>
        <Miscellaneous/>
        <Text/>
        <Color BackGround="lightblue"/>
        <Format/>
      </Field>
    </Tabular>
    <Color />
    </Frame>
  </Block>

  <!-- &DumpButton_Block; -->
  &StatusLine2_Block;
</Form>

<!-- vim: set fdl=5 foldmethod=syntax filetype=xml:-->
