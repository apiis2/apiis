<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Form PUBLIC "1" "form.dtd">
<Form Name="Codes_ff2">
  <General Name="G63" StyleSheet="/etc/apiis.css" Description="__('Keys')"/>

  <Block Name="B64" Description="Update codes">
     
    <DataSource Name="DS65" Connect="no">
      <Record TableName="codes"/>
      <Column DBName="class" Name="C46" Order="0" Type="DB"/>
      <Column DBName="ext_code" Name="C43" Order="1" Type="DB"/>
      <Column DBName="short_name" Name="C49" Order="2" Type="DB"/>
      <Column DBName="long_name" Name="C52" Order="3" Type="DB"/>
      <Column DBName="description" Name="C55" Order="4" Type="DB"/>
      <Column DBName="closing_dt" Name="C56" Order="5" Type="DB"/>
      <Column DBName="guid" Name="C62" Order="6" Type="DB"/>
    </DataSource>
      

    <Label Name="L41" Content="__('Create key')">
      <Position Column="0" Columnspan="3" Position="absolute" Row="0"/>
      <Text FontSize="24px" TextDecoration="underline"/>
    </Label>


    <Label Name="L45" Content="__('Class')">
      <Position Column="0" Position="absolute" Row="1"/>
    </Label>

    <Field Name="F47" DSColumn="C46" FlowOrder="1" >
      <DataSource Name="DataSource_1010">
        <Sql Statement="SELECT distinct class, class FROM entry_codes union select ext_code,ext_code from codes where class='CLASSES'"/>
      </DataSource>
      <ScrollingList Size="1"/>
      <Position Column="1" Position="absolute" Row="1"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="#ff6600"/>
      <Format/>
    </Field>
    <Label Name="L42" Content="__('External key')">
      <Position Column="0" Position="absolute" Row="2"/>
    </Label>

    <Field Name="F44" DSColumn="C43" FlowOrder="2" >
      <TextField Override="no" Size="10"/>
      <Position Column="1" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="#ff6600"/>
      <Format/>
    </Field>


    <Label Name="L48" Content="__('Short name')">
      <Position Column="0" Position="absolute" Row="3"/>
    </Label>

    <Field Name="F50" DSColumn="C49" FlowOrder="3" >
      <TextField Override="no" Size="20"/>
      <Position Column="1" Position="absolute" Row="3"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L51" Content="__('Full description')">
      <Position Column="0" Position="absolute" Row="4"/>
    </Label>

    <Field Name="F53" DSColumn="C52" FlowOrder="4" >
      <TextField Override="no" Size="40"/>
      <Position Column="1" Position="absolute" Row="4"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L54" Content="__('Description')">
      <Position Column="0" Position="absolute" Row="5"/>
    </Label>

    <Field Name="F56" DSColumn="C55" FlowOrder="5">
      <TextField Override="no" Size="95"/>
      <Position Column="1" Position="absolute" Row="5"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L1228" Content="__('Closed at')">
      <Position Column="0" Position="absolute" Row="6"/>
    </Label>

    <Field Name="F56x" DSColumn="C56" FlowOrder="6" >
      <TextField Override="no" Size="10" InputType="date"/>
      <Position Column="1" Position="absolute" Row="6"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    
    <Label Name="L61" Content="__('Internal ID')">
      <Position Column="0" Position="absolute" Row="7"/>
      <Format  PaddingBottom="10px"/>
    </Label>

    <Field Name="F63" DSColumn="C62" >
      <TextField Override="no" Size="10"/>
      <Position Column="1" Position="absolute" Row="7"/>
      <Miscellaneous Enabled="no"/>
      <Text />
      <Color BackGround="transparent" />
      <Format BorderColor="transparent"  PaddingBottom="10px"/>
    </Field>
    
    &NavigationButtons_Fields;
    &ActionButtons_Fields;
    &StatusLine_Block;

    <Color BackGround="#f0f0f0"/>
    <Format BorderStyle="ridge" BorderColor="#f0f0f0" Padding="10px"/>

  </Block>
</Form>
