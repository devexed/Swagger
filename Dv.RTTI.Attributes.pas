unit Dv.RTTI.Attributes;

interface

uses
  System.RTTI;

type

  LengthAttribute = class(TCustomAttribute)
  private
    FValue: Integer;
  public
    constructor Create(AValue: Integer);
    property Length: Integer read FValue;
  end;

  NameAttribute = class(TCustomAttribute)
  private
    FValue: string;
  public
    constructor Create(AValue: string);
    property Name: string read FValue;
  end;

  KeyAttribute = class(TCustomAttribute);

implementation

{ TLengthAttribute }

constructor LengthAttribute.Create(AValue: Integer);
begin
  FValue := AValue;
end;

{ TTableNameAttribute }

constructor NameAttribute.Create(AValue: string);
begin
  FValue := AValue;
end;

end.
