(*
  Copyright 2025, MARS-Curiosity - REST Library

  Home: https://github.com/andrea-magni/MARS
*)

unit Server.Ignition;

{$I MARS.inc}

interface

uses
  System.Classes, System.SysUtils, System.RTTI, System.StrUtils
{$IFDEF MARS_ZLIB}, System.ZLib {$ENDIF}
, MARS.Core.Engine.Interfaces
;

type
  TServerEngine=class
  private
    class var FEngine: IMARSEngine;
    {$IFDEF MARS_FIREDAC}
    class var FAvailableConnectionDefs: TArray<string>;
    {$ENDIF}
  public
    class constructor CreateEngine;
    class destructor DestroyEngine;
    class property Default: IMARSEngine read FEngine;
  end;

implementation

uses
  MARS.Core.Engine
, MARS.Core.Activation, MARS.Core.Activation.Interfaces
, MARS.Core.Application.Interfaces
, MARS.Core.Utils, MARS.Utils.Parameters.IniFile
, MARS.Core.URL, MARS.Core.RequestAndResponse.Interfaces
, MARS.Core.MessageBodyWriter
, MARS.Core.MessageBodyWriters
, MARS.Data.MessageBodyWriters
, MARS.Core.MessageBodyReaders
{$IFDEF MARS_FIREDAC}
, MARS.Data.FireDAC, FireDAC.Comp.Client, FireDAC.Stan.Option
{$ENDIF}
{$IFDEF MSWINDOWS}
, MARS.mORMotJWT.Token
{$ELSE}
, MARS.JOSEJWT.Token
{$ENDIF}
{$IFNDEF LINUX}
, MARS.YAML.ReadersAndWriters
{$ENDIF}
, MARS.OpenAPI.v3.InjectionService

, Server.Resources.HelloWorld
, Server.Resources.Token
, Server.Resources.OpenAPI
;

{ TServerEngine }

class constructor TServerEngine.CreateEngine;
begin
  FEngine := TMARSEngine.Create;

  // Engine configuration
  FEngine.Parameters.LoadFromIniFile;

  // Application configuration
  FEngine.AddApplication('DefaultApp', '/default', [ 'Server.Resources.*']);
{$REGION 'OnGetApplication example'}
(*
  FEngine.OnGetApplication :=
    procedure (
      const AEngine: IMARSEngine;
      const AURL: TMARSURL;
      const ARequest: IMARSRequest; const AResponse: IMARSResponse;
      var AApplication: IMARSApplication
    )
    begin
      if AApplication = nil then
        AApplication := FEngine.ApplicationByName('DefaultApp');
    end;
*)
{$ENDREGION}
  {$IFDEF MARS_FIREDAC}
  FAvailableConnectionDefs := TMARSFireDAC.LoadConnectionDefs(FEngine.Parameters, 'FireDAC');
  {$ENDIF}
{$REGION 'AfterCreateConnection example'}
(*
  TMARSFireDAC.AfterCreateConnection :=
    procedure (AConn: TFDConnection)
    begin
      AConn.TxOptions.Isolation := FEngine.Parameters.ByNameTextEnum<TFDTxIsolation>(
        'FireDAC.' + AConn.ConnectionDefName + '.TxOptions.Isolation'
      , TFDTxIsolation.xiUnspecified
      );
    end;
*)
{$ENDREGION}
{$REGION 'BeforeHandleRequest example'}

  FEngine.BeforeHandleRequest :=
    function (
      const AEngine: IMARSEngine;
      const AURL: TMARSURL;
      const ARequest: IMARSRequest; const AResponse: IMARSResponse;
      var Handled: Boolean
    ): Boolean
    begin
      Result := True;

      // skip favicon requests (browser)
      if SameText(AURL.Document, 'favicon.ico') then
      begin
        Result := False;
        Handled := True;
      end;

      if FEngine.IsCORSEnabled then
      begin
        // Handle CORS and PreFlight
        if SameText(ARequest.Method, 'OPTIONS') then
        begin
          Handled := True;
          Result := False;
        end;
      end;

    end;

{$ENDREGION}
{$REGION 'Global BeforeInvoke handler example'}
(*
  // to execute something before each activation
  TMARSActivation.RegisterBeforeInvoke(
    procedure (const AActivation: IMARSActivation; out AIsAllowed: Boolean)
    begin

    end
  );
*)
{$ENDREGION}
{$REGION 'Global AfterInvoke handler example'}
  // Compression
  if FEngine.Parameters.ByName('Compression.Enabled').AsBoolean then
    TMARSActivation.RegisterAfterInvoke(
      procedure (const AActivation: IMARSActivation)
      var
        LOutputStream: TBytesStream;
      begin
        if ContainsText(AActivation.Request.GetHeaderParamValue('Accept-Encoding'), 'gzip')  then
        begin
          LOutputStream := TBytesStream.Create(nil);
          try
            ZipStream(AActivation.Response.ContentStream, LOutputStream, 15 + 16);
            AActivation.Response.ContentStream.Free;
            AActivation.Response.ContentStream := LOutputStream;
            AActivation.Response.ContentEncoding := 'gzip';
          except
            LOutputStream.Free;
            raise;
          end;
        end;
      end
    );
{$ENDREGION}
{$REGION 'Global InvokeError handler example'}
(*
  // to execute something on error
  TMARSActivation.RegisterInvokeError(
    procedure (const AActivation: IMARSActivation; const AException: Exception; var AHandled: Boolean)
    begin

    end
  );
*)
{$ENDREGION}
end;

class destructor TServerEngine.DestroyEngine;
begin
  {$IFDEF MARS_FIREDAC}
  TMARSFireDAC.CloseConnectionDefs(FAvailableConnectionDefs);
  {$ENDIF}
  FEngine := nil;
end;

end.
