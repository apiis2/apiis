<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Form PUBLIC "1" "form.dtd">
<Form Name="F7">
  <General Name="G239" StyleSheet="/etc/apiis.css" Description="__('Create/modify event')"/>

  <Block Name="B240" Description="Update event">
     
    <DataSource Name="DS241" Connect="no">
      <Record TableName="event"/>
      <Column DBName="db_event_type" Name="C213" Order="1" Type="DB"/>
      <Column DBName="event_dt" Name="C216" Order="2" Type="DB"/>
      <Column DBName="db_location" Name="C219" Order="3" Type="DB"/>
      <Column DBName="db_sampler" Name="C228" Order="4" Type="DB"/>
      <Column DBName="guid" Name="C237" Order="5" Type="DB"/>
    </DataSource>
      

    <Label Name="L208" Content="__('Create/modify events')">
      <Position Column="1" Columnspan="3" Position="absolute" Row="0"/>
      <Text FontSize="24px" TextDecoration="underline"/>
    </Label>

    <Label Name="L212" Content="__('Eventtype'):">
      <Position Column="0" Position="absolute" Row="2"/>
    </Label>


    <Field Name="F214" DSColumn="C213" FlowOrder="1" InternalData="yes" Check="NotNull">
      <DataSource Name="DS241a" Connect="no">
        <Sql Statement="Select db_code, short_name from codes where class='EVENT' order by short_name"/>
      </DataSource>
      <ScrollingList Size="1"/>
      <Position Column="1" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color  BackGround="#11ff00"/>
      <Format/>
    </Field>

    <Label Name="L215" Content="__('Date'):">
      <Position Column="0" Position="absolute" Row="3"/>
    </Label>

    <Field Name="F217" DSColumn="C216" FlowOrder="2"  Check="NotNull" >
      <TextField Override="no" Size="10" InputType="date"/>
      <Position Column="1" Position="absolute" Row="3"/>
      <Miscellaneous/>
      <Text/>
      <Color  BackGround="#11ff00"/>
      <Format/>
    </Field>


    <Label Name="L218" Content="__('Location'):">
      <Position Column="0" Position="absolute" Row="4"/>
    </Label>

    <Field Name="F224" DSColumn="C219" FlowOrder="3" InternalData="yes"  Check="NotNull" >
      <DataSource Name="DS241b" Connect="no">
        <Sql Statement="select db_unit, ext_id || ' - '  || ext_unit as ext_unit from entry_unit where ext_unit='pruefort' or
        ext_unit='pruefstation' or ext_unit='koerort' or ext_unit='station' or ext_unit='auktion'  or
        ext_unit='slaughterhouse'
        order by ext_unit;"/>
      </DataSource>
      <ScrollingList Size="1" StartCompareString="left" ReduceEntries="yes" />
      <Position Column="1" Position="absolute" Row="4"/>
      <Miscellaneous/>
      <Text/>
      <Color  BackGround="#11ff00"/>
      <Format/>
    </Field>

    <Label Name="L227" Content="__('Testperson'):">
      <Position Column="0" Position="absolute" Row="5"/>
    </Label>

    <Field Name="F233" DSColumn="C228" FlowOrder="4" InternalData="yes" >
      <DataSource Name="DS241c" Connect="no">
        <Sql Statement="select db_unit, ext_id || ' - '  || ext_unit as ext_unit from entry_unit where ext_unit='pruefer' or
        ext_unit='us_tester' order by ext_unit;"/>
      </DataSource>
      <ScrollingList Size="1"  StartCompareString="left" ReduceEntries="yes"/>
      <Position Column="1" Position="absolute" Row="5"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <Label Name="L1243" Content="__('Internal ID')">
      <Position Column="0" Position="absolute" Row="14"/>
      <Format  PaddingBottom="10px"/>
    </Label>

    <Field Name="F1245" DSColumn="C237" FlowOrder="5" >
      <TextField Override="no" Size="8"/>
      <Position Column="1" Position="absolute" Row="14"/>
      <Miscellaneous Enabled="no"/>
      <Text/>
      <Color BackGround="transparent" />
      <Format BorderColor="transparent" PaddingBottom="10px"/>
    </Field>

    &NavigationButtons_Fields;
    &ActionButtons_Fields;
    &StatusLine_Block;


    <Color BackGround="#f0f0f0"/>
    <Format BorderStyle="ridge" BorderColor="#f0f0f0" Padding="10px"/>

  </Block>

</Form>
