# EBOOK

電子帳簿保存法で電子取引をした場合のデジタルデータを保存が義務化されました。  
2023年12月末まで猶予期間で2024年からは電子データを保存しなければなりません。  

EBOOKは以下のサービスを組み合わせて保存するシステムの構築を試みているものです。

- Sinatra
- LINE WORKS
- Hexabase
- S3
- Google Vision API


Protopediaに公開している記録も併せてご覧ください。

https://protopedia.net/prototype/3437

# 環境

開発は MacBook Pro (M1) で行っています。  
他の環境では動作しない箇所があるかもしれません。  

Rubyを使用します。使用したバージョンは以下のとおりです。

```
% ruby -v
ruby 3.1.2p20 (2022-04-12 revision 4491bb740a) [arm64-darwin21]
```

# セットアップ

## Ruby関連

このリポジトリのクローンを作るかZIPファイルをダウンロードし展開します。  
ターミナルでそのディレクトリに移動します。

bundleコマンドで必要なgemを準備します。  

```
% cd your/cron/of/reposotory
% bundle
```

## [LINE WORKS](https://pages.worksmobile.com/freeplan-branded.html)

こちらを参考に

[ワークスモバイルジャパン株式会社](https://qiita.com/organizations/worksmobile)で公開しているqiitaの記事を参考にLINE WORKSのテナントを開設しチャットボットを準備します。

[0から始めるLINE WORKS API](https://qiita.com/mmclsntr/items/3da41a9d03d6dba16290)


EBOOKには次の情報が必要になります。


- API 2.0サイドバーのメニューから作成したアプリを選択し、以下を確認します。
    - Client ID
    - Client Secret
    - Service Account
    - Private Key
- Botサイドバーのメニューから作成したBotを選択し、以下を確認します。
    - Bot ID
    - Bot Secret


## [Hexabase](https://www.hexabase.com)

[Hexabase開発ツアー](https://devdoc.hexabase.com/docs/)を参考にデータベースを作成します。

スキーマはこちらを参考に

![](https://i.gyazo.com/bd81e43efaf4d7c82c71c9879d9d8391.png)


EBOOKには次の情報が必要になります。

- APIサーバーのURL
- アカウントのメールアドレス
- アカウントのパスワード
- ワークスベースID
- プロジェクトディスプレイID
- データストアーディスプレイID

以下を参考にCLIツールをインストールします。

[Step4.CLIツールでアプリを登録する](https://devdoc.hexabase.com/docs/introduction/cli)

CLIツールで上記情報を取得します。


## [AWS S3](https://aws.amazon.com/jp/s3/)

S3のバケットを作成します。

EBOOKには次の情報が必要になります。

- リージョン
- アクセスキー
- シークレットアクセスキー
- バケット名


## [Google Vision API](https://cloud.google.com/vision/)


EBOOKには次の情報が必要になります。

- Credentialsファイルの中身
- Service account
- API KEY

## 環境変数設定

sample.envをコピーし.envファイルを作成します。
上記で集めた情報を環境変数として.envファイルに登録します。  

```
% cp sample.env .env
```

# 起動

app.rbスクリプトを実行しSinatraアプリを起動します。

```
% ruby app.rb
```

ローカルで動作させる場合にLINE WORKSのCallbackを受けれる様にngrokでプロキシサーバーを起動します。
ターミナルをもう一つ立ち上げ```rake proxy```コマンドでサーバーを起動します。


```
% rake proxy
ngrok                                                                                  (Ctrl+C 
.
.
Forwarding                    https://1dbd-240b-13-74e0-45f0-d4b0-d980-d6ec-797f.jp.ngrok.io -> http://

```

ForwardingにあるURLの末尾に'lineworks/callback'を加え、LINE WORSKSのBotのCallbackアドレスとして登録します。

上記の場合

```
https://1dbd-240b-13-74e0-45f0-d4b0-d980-d6ec-797f.jp.ngrok.io/lineworks/callback
```

# 動作確認

## 登録

LINE WORKSから'帳簿登録'と入力すると登録シーケンスが動作します。

## 検査

LINE WORKSから'帳簿検索'と入力すると登録シーケンスが動作します。

