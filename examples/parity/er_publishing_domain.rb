# frozen_string_literal: true

require 'slim_graph_r'

module ParityFixtures
  module ERPublishingDomain
    ENTITIES = {
      'Author' => ['# id uuid', 'handle text', 'name text', 'bio text', 'site_url text'],
      'Article' => ['# id uuid', 'title text', 'slug text · unique', 'body_mdx text', 'published_at timestamp', '→ author_id uuid', 'status enum', 'og_image text · url'],
      'Tag' => ['# id uuid', 'slug text · unique', 'name text', 'description text'],
      'ArticleTag' => ['→ article_id uuid', '→ tag_id uuid']
    }.freeze
    RELATIONSHIPS = [['Author', 'Article', '1', 'N', 'WRITES'], ['Article', 'ArticleTag', '1', 'N', nil], ['Tag', 'ArticleTag', '1', 'N', 'TAGGED']].freeze

    module_function

    def diagram(theme: :light, style: :editorial)

      SlimGraphR.diagram(:er, title: 'Publishing domain', theme: theme, style: style) do
        entity :author, 'Author' do
          field :id, 'id', key: :primary, type: 'uuid'
          field :handle, 'handle', type: 'text'
          field :name, 'name', type: 'text'
          field :bio, 'bio', type: 'text'
          field :site_url, 'site_url', type: 'text', qualifier: 'url'
        end
        entity :article, 'Article', kind: :aggregate_root, focal: true do
          field :id, 'id', key: :primary, type: 'uuid'
          field :title, 'title', type: 'text'
          field :slug, 'slug', type: 'text', qualifier: 'unique'
          field :body_mdx, 'body_mdx', type: 'text'
          field :published_at, 'published_at', type: 'timestamp'
          field :author_id, 'author_id', key: :foreign, type: 'uuid'
          field :status, 'status', type: 'enum'
          field :og_image, 'og_image', type: 'text', qualifier: 'url'
        end
        entity :tag, 'Tag' do
          field :id, 'id', key: :primary, type: 'uuid'
          field :slug, 'slug', type: 'text', qualifier: 'unique'
          field :name, 'name', type: 'text'
          field :description, 'description', type: 'text'
        end
        entity :article_tag, 'ArticleTag', kind: :join_table do
          field :article_id, 'article_id', key: :foreign, type: 'uuid'
          field :tag_id, 'tag_id', key: :foreign, type: 'uuid'
        end
        relationship :author, :article, from: '1', to: 'N', label: 'WRITES'
        relationship :article, :article_tag, from: '1', to: 'N'
        relationship :tag, :article_tag, from: '1', to: 'N', label: 'TAGGED'
      end
    end
  end
end
