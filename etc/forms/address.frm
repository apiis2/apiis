<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Form PUBLIC "1" "form.dtd">
<Form Name="F4">
  <General Name="G983" CharSet="utf8" StyleSheet="/etc/apiis.css" Description="__('Create/modify addresses')"/>

  <Block Name="B984" Description="Update address">
     
    <DataSource Name="DS985" Connect="no">
      <Record TableName="address"/>
      <Column DBName="firma_name" Name="C855" Order="0" Type="DB"/>
      <Column DBName="zu_haenden" Name="C858" Order="1" Type="DB"/>
      
      <Column DBName="db_title" Name="C873" Order="6" Type="DB"/>
      <Column DBName="db_salutation" Name="C876" Order="7" Type="DB"/>
      <Column DBName="first_name" Name="C879" Order="8" Type="DB"/>
      <Column DBName="second_name" Name="C882" Order="9" Type="DB"/>
      <Column DBName="ext_address" Name="C885" Order="10" Type="DB"/>
      <Column DBName="birth_dt" Name="C888" Order="11" Type="DB"/>
      <Column DBName="street" Name="C891" Order="12" Type="DB"/>
      <Column DBName="zip" Name="C894" Order="13" Type="DB"/>
      <Column DBName="town" Name="C897" Order="14" Type="DB"/>
      <Column DBName="county" Name="C900" Order="15" Type="DB"/>
      <Column DBName="db_country" Name="C903" Order="16" Type="DB"/>
      <Column DBName="db_language" Name="C906" Order="17" Type="DB"/>
      <Column DBName="phone_priv" Name="C909" Order="18" Type="DB"/>
      <Column DBName="phone_firma" Name="C912" Order="19" Type="DB"/>
      <Column DBName="phone_mobil" Name="C915" Order="20" Type="DB"/>
      <Column DBName="fax" Name="C918" Order="21" Type="DB"/>
      <Column DBName="email" Name="C921" Order="22" Type="DB"/>
      <Column DBName="http" Name="C924" Order="23" Type="DB"/>
      <Column DBName="comment" Name="C927" Order="24" Type="DB"/>
      <Column DBName="hz" Name="C930" Order="25" Type="DB"/>
      <Column DBName="bank" Name="C936" Order="27" Type="DB"/>
      <Column DBName="iban" Name="C942" Order="29" Type="DB"/>
      <Column DBName="db_payment" Name="C945" Order="30" Type="DB"/>
      <Column DBName="member_entry_dt" Name="C948" Order="31" Type="DB"/>
      <Column DBName="member_exit_dt" Name="C951" Order="32" Type="DB"/>
      <Column DBName="guid" Name="C982" Order="43" Type="DB"/>
    </DataSource>
      

    <Label Name="L850" Content="__('Addressmanager'):">
      <Position Column="0" Columnspan="5" Position="absolute" Row="0"/>
      <Text FontSize="24px" TextDecoration="underline"/>
    <Format PaddingBottom="14px" />
    </Label>

    <Label Name="L851" Content="__('External key'):">
      <Position Column="0" Position="absolute" Row="1"/>
      <Text FontSize="12px"/>
    </Label>
    <Field Name="F886" DSColumn="C885" FlowOrder="1" >
      <TextField Override="no" Size="10"/>
      <Position Column="0" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="#00ffff"/>
      <Format/>
    </Field>
    <Label Name="L929" Content="__('Abbreviation'):">
      <Position Column="1" Position="absolute" Row="1"/>
      <Text FontSize="12px"/>
    </Label>
    <Field Name="F931" DSColumn="C930" FlowOrder="2" >
      <TextField Override="no" Size="10"/>
      <Position Column="1" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format  MarginRight="5px"/>
    </Field>


    <Label Name="L854" Content="__('Company'):">
      <Position Column="0" Position="absolute" Row="3"/>
      <Text FontSize="12px"/>
    </Label>
    <Field Name="F856" DSColumn="C855" FlowOrder="3" >
      <TextField Override="no" Size="70"/>
      <Position Column="0" Columnspan="2" Position="absolute" Row="4"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Label Name="L857" Content="__('Contact person')">
      <Position Column="2" Position="absolute" Row="3"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F859" DSColumn="C858" FlowOrder="4" >
      <TextField Override="no" Size="25"/>
      <Position Column="1" Position="absolute" Row="4"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <Label Name="L872" Content="__('Title / salutation')">
      <Position Column="0" Position="absolute" Row="5"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F874" DSColumn="C873" FlowOrder="9" InternalData="yes" >
      <DataSource Name="DataSource_F874">
        <Sql Statement="SELECT 	db_code, ext_code || ' - ' || short_name FROM codes WHERE class='Titel' or class='TITLE'"/>
      </DataSource>
      <ScrollingList Size="1"/>
      <Position Column="0" Position="absolute" Row="6"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format  MarginRight="5px"/>
    </Field>
    <Field Name="F877" DSColumn="C876" FlowOrder="10"  InternalData="yes" >
      <DataSource Name="DataSource_ff1_1">
        <Sql Statement="SELECT 	db_code, ext_code || ' - ' || short_name FROM codes WHERE class='SALUTATION'"/>
      </DataSource>
      <ScrollingList Size="1"/>
      <Position Column="0" Position="absolute" Row="6"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Label Name="L878" Content="__('First name')">
      <Position Column="1" Position="absolute" Row="5"/>
      <Text FontSize="12px"/>
    </Label>
    <Field Name="F880" DSColumn="C879" FlowOrder="11" >
      <TextField Override="no" Size="20"/>
      <Position Column="1" Position="absolute" Row="6"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Label Name="L881" Content="__('Second name')">
      <Position Column="2" Position="absolute" Row="5"/>
      <Text FontSize="12px"/>
    </Label>
    <Field Name="F883" DSColumn="C882" FlowOrder="12" >
      <TextField Override="no" Size="25"/>
      <Position Column="2" Position="absolute" Row="6"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>



    <Label Name="L893" Content="__('Postcode / town')">
      <Position Column="0" Position="absolute" Row="11"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F895" DSColumn="C894" FlowOrder="13" >
      <TextField Override="no" Size="5"/>
      <Position Column="0" Position="absolute" Row="12"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format MarginRight="5px"/>
    </Field>
    <Field Name="F898" DSColumn="C897" FlowOrder="14" >
      <TextField Override="no" Size="20"/>
      <Position Column="0" Position="absolute" Row="12"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Label Name="L890" Content="__('Street')">
      <Position Column="1" Position="absolute" Row="11"/>
      <Text FontSize="12px"/>
    </Label>
    <Field Name="F892" DSColumn="C891" FlowOrder="15" >
      <TextField Override="no" Size="30"/>
      <Position Column="1" Position="absolute" Row="12"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <Label Name="L899" Content="__('County')">
      <Position Column="2" Position="absolute" Row="11"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F901" DSColumn="C900" FlowOrder="16" >
      <TextField Override="no" Size="20"/>
      <Position Column="2" Position="absolute" Row="12"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L902" Content="__('Country')">
      <Position Column="3" Position="absolute" Row="11"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F904" DSColumn="C903" FlowOrder="17"  InternalData="yes" >
      <DataSource Name="DataSource_F8741">
        <Sql Statement="SELECT 	db_code, ext_code || ' - ' || short_name FROM codes WHERE class='COUNTRY'"/>
      </DataSource>
      <ScrollingList Size="1"/>
      <Position Column="3" Position="absolute" Row="12"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    <Label Name="L905" Content="__('Language')">
      <Position Column="4" Position="absolute" Row="11"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F907" DSColumn="C906" FlowOrder="18"  InternalData="yes" >
      <DataSource Name="DataSource_F8742">
        <Sql Statement="SELECT 	db_code, ext_code || ' - ' || short_name FROM codes WHERE class='LANGUAGE'"/>
      </DataSource>
      <ScrollingList Size="1"/>
      <Position Column="4" Position="absolute" Row="12"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L908" Content="__('Phone (priv.)'):">
      <Position Column="0" Position="absolute" Row="13"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F910" DSColumn="C909" FlowOrder="19" >
      <TextField Override="no" Size="20"/>
      <Position Column="0" Position="absolute" Row="14"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L911" Content="__('Phone (offic.)')">
      <Position Column="1" Position="absolute" Row="13"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F913" DSColumn="C912" FlowOrder="20" >
      <TextField Override="no" Size="20"/>
      <Position Column="1" Position="absolute" Row="14"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L914" Content="__('Phone (mobil)')">
      <Position Column="2" Position="absolute" Row="13"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F916" DSColumn="C915" FlowOrder="21" >
      <TextField Override="no" Size="20"/>
      <Position Column="2" Position="absolute" Row="14"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L917" Content="__('Fax')">
      <Position Column="0" Position="absolute" Row="15"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F919" DSColumn="C918" FlowOrder="22" >
      <TextField Override="no" Size="20"/>
      <Position Column="0" Position="absolute" Row="16"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L920" Content="__('eMail')">
      <Position Column="1" Position="absolute" Row="15"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F922" DSColumn="C921" FlowOrder="23" >
      <TextField Override="no" Size="30"/>
      <Position Column="1" Position="absolute" Row="16"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L923" Content="__('Internet')">
      <Position Column="2" Position="absolute" Row="15"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F925" DSColumn="C924" FlowOrder="24" >
      <TextField Override="no" Size="30"/>
      <Position Column="2" Position="absolute" Row="16"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    



    <Label Name="L935" Content="__('Bank')">
      <Position Column="0" Position="absolute" Row="17"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F937" DSColumn="C936" FlowOrder="25" >
      <TextField Override="no" Size="25"/>
      <Position Column="0" Position="absolute" Row="18"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L941" Content="__('Account')">
      <Position Column="2" Position="absolute" Row="17"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F943" DSColumn="C942" FlowOrder="27" >
      <TextField Override="no" Size="10"/>
      <Position Column="2" Position="absolute" Row="18"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L944" Content="__('Payment')">
      <Position Column="3" Position="absolute" Row="17"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F946" DSColumn="C945" FlowOrder="28"  InternalData="yes" >
      <DataSource Name="DataSource_F8745">
        <Sql Statement="SELECT 	db_code, ext_code || ' - ' || short_name FROM codes WHERE class='PAYMENT' order by ext_code"/>
      </DataSource> 
      <ScrollingList Size="1"/>
      <Position Column="3" Position="absolute" Row="18"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>
    
    <Label Name="L887" Content="__('Birth date')">
      <Position Column="0" Position="absolute" Row="19"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F889" DSColumn="C888" FlowOrder="29" >
      <TextField Override="no" Size="10"/>
      <Position Column="0" Position="absolute" Row="20"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <Label Name="L947" Content="__('Member since')">
      <Position Column="1" Position="absolute" Row="19"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F949" DSColumn="C948" FlowOrder="30" >
      <TextField Override="no" Size="10"/>
      <Position Column="1" Position="absolute" Row="20"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Label Name="L950" Content="__('Member to')">
      <Position Column="2" Position="absolute" Row="19"/>
                  <Text FontSize="12px"/>
    </Label>

    <Field Name="F952" DSColumn="C951" FlowOrder="31" >
      <TextField Override="no" Size="10"/>
      <Position Column="2" Position="absolute" Row="20"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>

    <Label Name="L926" Content="__('Remarks')">
      <Position Column="0" Position="absolute" Row="21"/>
      <Text FontSize="12px"/>
    </Label>

    <Field Name="F928" DSColumn="C927" FlowOrder="32" >
      <TextField Override="no" Size="110"/>
      <Position Column="0" Columnspan="4" Position="absolute" Row="22"/>
      <Miscellaneous/>
      <Text/>
      <Color/>
      <Format/>
    </Field>


    <Field Name="F982a" DSColumn="C982" >
      <TextField Override="no" Size="10"/>
      <Position Column="0" Position="absolute" Row="26"/>
      <Miscellaneous Enabled="no"/>
      <Text/>
      <Color BackGround="transparent"/>
      <Format BorderColor="transparent"/>
    </Field>
    
    &NavigationButtons_Fields;
    &ActionButtons_Fields;
    &StatusLine_Block;

    <Color BackGround="#f0f0f0"/>
    <Format BorderStyle="ridge" BorderColor="#f0f0f0" MarginTop="12px"/>

  </Block>
</Form>
