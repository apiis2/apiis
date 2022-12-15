<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE Form SYSTEM "form.dtd">
<Form Name="login_form">
  <General Author="$Author: heli $" Cvs="$Id: login.frm,v 1.1 2006/09/22 07:52:12 heli Exp $"
    Description="Login" Name="General_0" Version="$Revision: 1.1 $"/>

  <Block Description="main block" Name="Block_0">
    <DataSource Name="none">
       <none/>
    </DataSource>

    <Label Name="Label_0"  Content="Login name">
        <Position Column="0" Row="0"/>
    </Label>
    <Label Name="Label_1"  Content="Password">
        <Position Column="0" Row="1"/>
    </Label>

    <Field Name="Field_0" Description="login name">
      <TextField Size="15"/>
      <Position Column="1" Row="0"/>
      <Miscellaneous Visibility="visible" Enabled="yes"/>
      <Text/>
      <Color BackGround="lightgray"/>
      <Format/>
    </Field>
    <Field Name="Field_1" Description="password">
      <TextField Size="15" Password="yes"/>
      <Position Column="1" Row="1"/>
      <Miscellaneous Visibility="visible" Enabled="yes"/>
      <Text/>
      <Color BackGround="lightgray"/>
      <Format/>
    </Field>

    <!-- Buttons -->
    <Field Description="Start authentication" Name="Field_login">
      <Button ButtonLabel="Login" Command="do_exit"/>
      <Position Column="0" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="green"/>
      <Format/>
    </Field>
    <Field Description="Cancel authentication" Name="Field_cancel">
      <Button ButtonLabel="Cancel" Command="do_clear_form_and_die"/>
      <Position Column="1" Position="absolute" Row="2"/>
      <Miscellaneous/>
      <Text/>
      <Color BackGround="red"/>
      <Format/>
    </Field>

  </Block>
</Form>

<!-- vim: set fdl=5 foldmethod=syntax filetype=xml:-->
