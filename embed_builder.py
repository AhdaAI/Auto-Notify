from dataclasses import asdict, dataclass


@dataclass
class EmbedFooter:
    text: str
    icon_url: str | None = None


@dataclass
class EmbedImage:
    url: str


@dataclass
class EmbedThumbnail:
    url: str


@dataclass
class EmbedVideo:
    url: str


@dataclass
class EmbedProvider:
    name: str
    url: str | None = None


@dataclass
class EmbedAuthor:
    name: str
    url: str | None = None
    icon_url: str | None = None


@dataclass
class EmbedField:
    name: str
    value: str
    inline: bool = True


@dataclass
class Embed:
    title: str
    description: str | None = None
    url: str | None = None
    timestamp: str | None = None
    color: int | None = None
    footer: EmbedFooter | None = None
    image: EmbedImage | None = None
    thumbnail: EmbedThumbnail | None = None
    video: EmbedVideo | None = None
    provider: EmbedProvider | None = None
    author: EmbedAuthor | None = None
    fields: list[EmbedField] | None = None

    def to_dict(self):
        return {k: v for k, v in asdict(self).items() if v is not None}
