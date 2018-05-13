unit DemoTypes;

interface

uses
  Dv.Types, Dv.Rtti.Attributes;

type

  TArborder = class
  private
    FId: TGUID;
    FNummer: Nullable<string>;
    FArbetsplats: string;
    FStatus: Integer;
    FByggMoms: Boolean;
  protected
    FStatusCaption: string;
  public
    [Key]
    property Id: TGUID read FId write FId;
    [MaxLength(15)]
    property Nummer: Nullable<string> read FNummer write FNummer;
    [MaxLength(35)]
    property Arbetsplats: string read FArbetsplats write FArbetsplats;
    property Status: Integer read FStatus write FStatus;
    property ByggMoms: Boolean read FByggMoms write FByggMoms;
    [MaxLength(35)]
    property StatusCaption: string read FStatusCaption;
  end;

  [Name('KONTON')]
  TKonto = class
  private
    FKonto: string;
    FId: TGUID;
    FBenamning: string;
  public
    [Key]
    property Id: TGUID read FId write FId;
    [MaxLength(4)]
    property Konto: string read FKonto write FKonto;
    [MaxLength(30)]
    property Benamning: string read FBenamning write FBenamning;
  end;

implementation

end.
