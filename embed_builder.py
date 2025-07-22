"""Embed Builder

Builder class to help in building the embed.
"""
from dataclasses import asdict, dataclass
from datetime import datetime


@dataclass(frozen=True)
class EmbedType:
    """
    Represents the different types of Discord embed objects.

    Attributes:
        rich (str): Standard rich embed type, supports most embed fields.
        image (str): Embed type for images.
        video (str): Embed type for videos.
        gifv (str): Animated GIF image embed rendered as a video embed.
        article (str): Embed type for articles.
        link (str): Embed type for links.
        poll_result (str): Embed type for poll results. See Discord documentation for supported fields.
    """
    rich: str = "rich"
    image: str = "image"
    video: str = "video"
    gifv: str = "gifv"  # * animated gif image embed rendered as a video embed
    article: str = "article"
    link: str = "link"
    # ! see https://discord.com/developers/docs/resources/message#embed-fields-by-embed-type-poll-result-embed-fields
    poll_result: str = "poll_result"


@dataclass
class FooterObject:
    """
    Represents the footer section of a Discord embed.

    Attributes:
        text (str): Footer text.
        icon_url (str): URL of the footer icon.
        proxy_icon_url (str): Proxy URL of the footer icon.
    """
    text: str | None = None
    icon_url: str | None = None
    proxy_icon_url: str | None = None


@dataclass
class ImageObject:
    """
    Represents the image section of a Discord embed.

    Attributes:
        url (str): Source URL of the image.
        proxy_url (str): Proxy URL of the image.
        height (int): Height of the image.
        width (int): Width of the image.
    """
    url: str
    proxy_url: str | None = None
    height: int | None = None
    width: int | None = None


@dataclass
class ThumbnailObject:
    """
    Represents the thumbnail section of a Discord embed.

    Attributes:
        url (str): Source URL of the thumbnail.
        proxy_url (str): Proxy URL of the thumbnail.
        height (int): Height of the thumbnail.
        width (int): Width of the thumbnail.
    """
    url: str
    proxy_url: str | None = None
    height: int | None = None
    width: int | None = None


@dataclass
class VideoObject:
    """
    Represents the video section of a Discord embed.

    Attributes:
        url (str): Source URL of the video.
        proxy_url (str): Proxy URL of the video.
        height (int): Height of the video.
        width (int): Width of the video.
    """
    url: str
    proxy_url: str | None = None
    height: int | None = None
    width: int | None = None


@dataclass
class ProviderObject:
    """
    Represents the provider section of a Discord embed.

    Attributes:
        name (str): Name of the provider.
        url (str): URL of the provider.
    """
    name: str
    url: str


@dataclass
class AuthorObject:
    """
    Represents the author section of a Discord embed.

    Attributes:
        name (str): Name of the author.
        url (str): URL of the author.
        icon_url (str): URL of the author's icon.
        proxy_icon_url (str): Proxy URL of the author's icon.
    """
    name: str
    url: str | None = None
    icon_url: str | None = None
    proxy_icon_url: str | None = None


@dataclass
class FieldObject:
    """
    Represents a field object in a Discord embed.

    Attributes:
        name (str): Name of the field.
        value (str): Value of the field.
        inline (bool): Whether the field is displayed inline.
    """
    name: str
    value: str
    inline: bool = True


@dataclass
class Embed:
    """
    Represents a Discord embed object.

    Attributes:
        title (str): Title of the embed.
        description (str): Description text.
        url (str): URL of the embed.
        timestamp (datetime): Timestamp of the embed content.
        color (str): Color code of the embed.
        footer (FooterObject): Footer section.
        image (ImageObject): Image section.
        thumbnail (ThumbnailObject): Thumbnail section.
        video (VideoObject): Video section.
        provider (ProviderObject): Provider section.
        author (AuthorObject): Author section.
        fields (list[FieldObject]): List of embed fields.
        type (EmbedType): Type of the embed.
    """
    title: str
    description: str | None = None
    url: str | None = None
    timestamp: datetime | None = None
    # ! see https://gist.github.com/thomasbnt/b6f455e2c7d743b796917fa3c205f812
    color: str | None = None
    footer: FooterObject | None = None
    image: ImageObject | None = None
    thumbnail: ThumbnailObject | None = None
    video: VideoObject | None = None
    provider: ProviderObject | None = None
    author: AuthorObject | None = None
    fields: list[FieldObject] | None = None
    type: EmbedType | str = EmbedType.rich

    def to_dict(self):
        """
        Converts the Embed object to a dictionary.

        Returns:
            dict: Dictionary representation of the embed.
        """
        return asdict(self)
