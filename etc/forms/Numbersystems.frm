<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Form PUBLIC "1" "form.dtd">
<Form Name="F11">
  <General Name="G1246" StyleSheet="/etc/apiis.css" Description="__('Unit numbersystem')"/>

  <Block Name="B1247" Description="Update unit">
     
    <DataSource Name="DS1248" Connect="no">
      <Record TableName="unit"/>
      <Column DBName="db_unit" Name="C1197" Order="0" Type="DB"/>
      <Column DBName="ext_unit" Name="C1200" Order="1" Type="DB"/>
      <Column DBName="ext_id" Name="C1203" Order="2" Type="DB"/>
      <Column DBName="guid" Name="C1244" Order="10" Type="DB"/>
    </DataSource>
      

    <Label Name="L1195" Content="__('Create units for numbersystem')">
      <Position Column="0" Columnspan="2" Position="absolute" Row="0"/>
      <Text FontSize="24px" TextDecoration="underline"/>
      <Format PaddingBottom="10px"/>
    </Label>

    <Field Name="F1198" DSColumn="C1197" >
      <TextField Override="no" Size="10"/>
      <Position Column="1" Position="absolute" Row="1"/>
      <Miscellaneous Visibility="hidden" Enabled="no"/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L1199" Content="__('Nummernsystem')">
      <Position Column="0" Position="absolute" Row="2"/>
    </Label>

    <Field Name="F1201" DSColumn="C1200" FlowOrder="1" Check="NotNull" >
      <DataSource Name="DS1248a" Connect="no">
        <Sql Statement="Select distinct ext_code, short_name from codes where class='ID_SET'"/>
      </DataSource>
      
      <ScrollingList Size="1"/>
      <Position Column="1" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="#ffff00"/>
      <Format/>
    </Field>

    <Label Name="L1202" Content="__('Unit')">
      <Position Column="0" Position="absolute" Row="3"/>
    </Label>

    <Field Name="F1204" DSColumn="C1203" FlowOrder="2" >
      <TextField Override="no" Size="20"/>
      <Position Column="1" Position="absolute" Row="3"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="#ffff00"/>
      <Format/>
    </Field>

    <Field Name="F1245" DSColumn="C1244" FlowOrder="3" >
      <TextField Override="no" Size="8"/>
      <Position Column="1" Position="absolute" Row="4"/>
      <Miscellaneous Enabled="no" />
      <Text/>
      <Color BackGround="transparent"/>
      <Format BorderColor="transparent"/>
    </Field>

    &NavigationButtons_Fields;
    &ActionButtons_Fields;
    &StatusLine_Block;


    <Color BackGround="#f0f0f0"/>
    <Format BorderStyle="ridge" BorderColor="#f0f0f0" Padding="10px"/>

  </Block>
</Form>
