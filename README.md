# AWS CloudFormation Development Kit

This is easy operation/integration support tool for AWS CloudFormation.
This tool drives DevOps and Infrastructure as Code.

[![CircleCI](https://circleci.com/gh/Amakata/cfndk/tree/master.svg?style=svg)](https://circleci.com/gh/Amakata/cfndk/tree/master)

このツールは、AWS CloudFromationのための簡単な運用/構築サポートツールです。

kumogata, SparkleFormation, CoffeeFormation など、CloudFormationのテンプレートを書かずにDSLで表現するツールには様々な物があります。
しかし、これらのツールはサードパーティツールであるため、CloudFormationの対応への追従に不安がのこります。
本ツールは、標準のCloudFromationテンプレートの枠組みを変えずに、その利用を支援するツールをを目指しています。
最悪の場合、このツールが使えなくなっても僅かなコストで標準のAWS CLIを使いオペレーションを続行することが可能です

## ハイライト

* 複数のスタックをワンコマンドで作成/更新/削除
* 複数のスタックの依存関係を考慮した操作
* CloudFormationでバージョンコントロールシステムと連動した継続的インテグレーションのための基盤対応
* Keypairの作成/削除
* コマンド、サブコマンド、冪統性を考慮したコマンドライン体系、オプションの整理、ヘルプの追加
* チェンジセットの作成/実行/削除/レポート
* Keypair/スタック毎のregionのサポート
* 512000バイト以上の大きなテンプレートファイルの場合に自動的にS3にテンプレートファイルをアップロードして処理する機能
* aws cloudformation package相当の機能(nested templateやlambda functionの自動アップロード) (experimental)
* cfndk全体での共通設定

## Install

```
$ gem install cfndk
```

## Usage

```
$ mkdir cfn-project
$ cd cfn-project
$ cfndk init
$ export AWS_REGION=ap-northeast-1
$ export AWS_PROFILE=default
$ cfndk create
$ cfndk report
$ cfndk destroy -f
```

## Credentials configuration

次の順番でCredentialsを評価して最初に有効なCredentialsを使用します。

1. access key、secret access key、session token環境変数よるCredentials
   * ACCESS_KEYで利用される環境変数名: AWS_ACCESS_KEY_ID AMAZON_ACCESS_KEY_ID AWS_ACCESS_KEY
   * SECRET_ACCESS_KEYで利用される環境変数名: AWS_SECRET_ACCESS_KEY AMAZON_SECRET_ACCESS_KEY AWS_SECRET_KEY
   * SESSION_TOKEで利用される環境変数名: AWS_SESSION_TOKEN AMAZON_SESSION_TOKEN
2. AWS_PROFILE環境変数によるProfileのaccess key、secret access key、session tokenによるCredentials
   * 環境変数が指定されない場合は、defaultが利用されます。
3. AWS_PROFILE環境変数によるProfileのcredential_processによるCredentials
   * 環境変数が指定されない場合は、defaultが利用されます。
4. EC2/ECS Instance ProfileによるCredentials
   * AWS_CONTAINER_CREDENTIALS_RELATIVE_URI環境変数が設定された場合のみECSが使われます。

## Command

### ```init```

カレントディレクトリにcfndk.ymlのひな形を作成します。

```
cfndk init
```

### ```create```

cfndk.ymlで定義されているキーペアとスタックを作成します。

```cfndk create [option]```


### ```destroy```

cfndk.ymlで定義されているるキーペアとスタックを削除します。

```
cfndk destroy [option]
```

### ```generate-uuid```

UUIDを生成して標準出力に出力します。

```
cfndk generate-uuid
```

例えば次のような使い方をします。

```
export CFNDK_UUID=`cfndk generate-uuid`
cfndk create
cfndk destroy
unset CFNDK_UUID
```

### ```report```

cfndk.ymlで定義されているスタックについてレポートします。

```
cfndk report [option]
```
### ```keypair```

cfndk.ymlで定義されているキーペアの作成/削除を行うサブコマンドです。

詳細は

```
cfndk keypair help
```

で確認できます。

### ```stack```

cfndk.ymlで定義されているスタックの作成/更新/削除/レポート/テンプレート検証を行うサブコマンドです。

詳細は

```
cfndk stack help
```

で確認できます。


### ```changeset``` (experimental)

cfndk.ymlで定義されているスタックのチェンジセットの作成/実行/削除/レポートを行うサブコマンドです。

詳細は

```
cfndk changeset help
```

で確認できます。

### option

#### ```-v --verbose```

実行時に詳細な情報を表示します。

#### ```-c, --config-path=cfndk.yml```

カレントディレクトリのcfndi.ymlの代わりに、ファイルを指定します。

#### ```-p, --properties=name:value```

プロパティを追加します。
cfndi.ymlのparametersのerb内で値で参照することができます。

####  ```-u, --uuid uuid```

スタック名、チェンジセット名に指定されたUUIDを使用します。
UUIDが指定されるとスタック名、チェンジセット名に付加されます。
またcfndi.ymlのparametersの値で参照することができます。

スタック名は下記のようになります。
何も指定されない場合はcfndk.ymlで定義されたスタック名がそのまま使われます。

```[Stack Original Name]-[Stack's UUID]```

####  ```--change-set-uuid uuid```

チェンジセット名に指定されたUUIDを使用します。
UUIDが指定されるとチェンジセット名に付加されます。

このオプションが指定された場合チェンジセット名は下記のようになります。
何も指定されない場合はチェンジセット名にはスタック名がそのまま使われます。

```[Stack Name]-[Changeset's UUID]```


#### ```--stack-names=name1 name2```

指定されたスタック名のみを操作します。

#### ```--keypair-names=name1 name2```

指定されたキーペア名のみを操作します。


#### ```--no-color```

メッセージ出力でカラーを抑制します。

### ```-f, --force```

動作の確認メッセージと入力をスキップします。

他にもオプションはあります。
詳細はコマンドヘルプを参照してください。

## Environment Variables

### ```CFNDK_UUID```

この環境変数が指定されている場合、```--uuid $CFNDK_UUID```が指定されたものとして動作します。
```--uuid```のほうが優先されます。

### ```CFNDK_CHANGE_SET_UUID```

この環境変数が指定されている場合、```--change-set-uuid $CFNDK_CHANGE_SET_UUID```が指定されたものとして動作します。

## cfndk.yml

* example

```
global:
  region: ap-northeast-1
  s3_template_bucket: cfndk-templates
  timeout_in_minutes: 10
  package: true
  default_profile: profile_name
keypairs:
  Key1:
    region: us-east-1
  Key2:
    key_file: key/key2<%= append_uuid %>.pem
stacks:
  Stack1:
    region: us-east-1
    template_file: stack1/stack1.yaml 
    parameter_input: stack1/env.json
    parameters:
      VpcName: Prod<%= append_uuid %>
    package: true
  Stack2:
    template_file: stack2/stack2.yaml 
    parameter_input: stack2/env.json
    parameters:
      VpcName: Prod<%= append_uuid %>
    capabilities:
      - CAPABILITY_IAM
      - CAPABILITY_NAMED_IAM
    depends:
      - Stack1
    timeout_in_minutes: 10
```

```
global:
  region: [String]
  s3_template_bucket: [String]
  timeout_in_minutes: [Integer]
  package: [Boolean]
  default_profile: [String]
keypairs:
  [String]:
    region: [String]
    key_file: [String]
stacks:
  [String]:
    region: [String]
    template_file: [String]
    parameter_input: [String]
    parameters:
      [String]: [String]
      [String]: [String]   
    capabilities:
      - [String]
      - [String]
    timeout_in_minutes: [Integer]
    depends:
      - [String]
      - [String]
    package: [Boolean]
    enabled: [Boolean]
```

### ```global:```

全体設定を定義します。

#### region (デフォルト: us-east-1)

全体で利用するリージョンを指定します。
指定されない場合は、AWS_REGION環境変数の値をリージョンとして使用します。
AWS_REGIONも指定されない場合はus-east-1を利用します。

#### timeout_in_minutes (デフォルト: 1)

全体で利用するタイムアウト時間を分で指定します。

#### s3_template_bucket (デフォルト: cfndk-templates)

スタックのCloudFormationテンプレートファイルをアップロードするS3のバケット名を指定します。

実際のバケット名は
```
[region]-[s3_template_bucket]
```
が使用されます。
regionはスタック毎で指定されたものを利用します。

S3バケットは一日で自動的に中身のオブジェクトが削除されるように設定されます。

#### package (デフォルト: false)

trueを指定した場合に、
スタックのテンプレートで、ネステッドスタックや、CloudFormationのコードがローカルパス形式で指定されている場合に
```aws cloudformation package```
相当の処理を行います。

yaml、jsonの意図しない加工がされる可能性があるためデフォルトではfalseとなっています。

例えば、```package: true```を指定して下記の様に記述すると、 ```./lambda_function``` フォルダをzipアーカイブしてS3にアップロードし、Codeを適切なS3のパスに更新します。

```
  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      Code: ./lambda_function
```

#### default_profile

default_profileで指定されたAWSプロファイルを利用してスタックを作成します。
AWS_PROFILE環境変数が指定された場合にはAWS_PROFILE環境変数が優先して使用されます。

### ```keypairs:```

```
keypairs:
  [keypair Original Name]:
```

cfndkで管理するキーペアを定義します。
キーペアの配下には、管理するキーペアのオリジナル名を定義します。
通常は、キーペアを作成するとこの名称が利用されます。
UUIDを利用すると、```[Keypair Original Name]-[UUID]```のような形式のキーペア名が利用されます。

#### region

キーペアのリージョンを指定します。
globalのregionより優先されます。

#### key_file

キーペア作成時にキーペアのファイルを指定された相対パスに作成します。
同名のファイルがある場合は上書きするので注意が必要です。

erbの記法が利用できます。

```
    key_file: key/key<%= append_uuid %>.pem
```


### ```stacks:```

```
stacks:
  [Stack Original Name]:
```

cfndkで管理するスタックを定義します。
stacksの配下には、管理するスタックのオリジナル名を定義します。
通常は、stackを作成するとこの名称が利用されます。
UUIDを利用すると、```[Stack Original Name]-[UUID]```のような形式のスタック名が利用されます。

#### region

スタックのリージョンを指定します。
globalのregionより優先されます。

#### template_file 

必須。CloudFormationテンプレートファイルのパスをcfndk.ymlからの相対パスで指定します。

#### parameter_input

必須。CloudFormationのパラメータJSONファイルをcfndk.ymlからの相対パスで指定します。

#### parameters

parameter_inputのJSONの値を上書きした場合に指定します。
複数指定することができます。

```
    parameters:
      [Parameter Key1]: [Parameter Value1]
      [Parameter Key2]: [Parameter Value2]
```

Parameter Valueではerbの記法が利用できます。

```
    parameters:
      VpcName: Prod<%= append_uuid %>
```

#### capabilities

スタックを操作するcapabilitiesを指定します。
複数指定することができます。

```
    capabilities:
      - CAPABILITY_IAM
      - CAPABILITY_NAMED_IAM
```

以下の値を指定することができます。

* CAPABILITY_IAM
* CAPABILITY_NAMED_IAM
* CAPABILITY_AUTO_EXPAND


#### depends

スタックに依存している別のスタックを指定します。
複数指定することができます。
dependsを指定すると、create,update,create-or-changeset,destoryのコマンドを実行する際に、依存関係に従ってスタックを処理します。
存在しないタスタックやdependsが循環するような指定をすることはできません。

```
    depends:
      - Stack1
      - Stack2  
```

#### package (デフォルト: false)

trueを指定した場合に、
スタックのテンプレートで、ネステッドスタックや、CloudFormationのコードがローカルパス形式で指定されている場合に
```aws cloudformation package```
相当の処理を行います。

yaml、jsonの意図しない加工がされる可能性があるためデフォルトではfalseとなっています。

例えば、```package: true```を指定して下記の様に記述すると、 ```./lambda_function``` フォルダをzipアーカイブしてS3にアップロードし、Codeを適切なS3のパスに更新します。

```
  LambdaFunction:
    Type: AWS::Lambda::Function
    Properties:
      Code: ./lambda_function
```

#### enabled　(デフォルト: true)

falseを指定した場合、そのスタックを無視します

#### timeout_in_minutes

スタックを作成する際などのタイムアウト時間を分で指定します。

```
    timeout_in_minutes: 5
```


### erbで使用できるメソッド

  * ```append_uuid(glue='-')```

    スタックのUUIDガ指定されている場合、```[glueの文字列] + [Stack's UUID]```を返します。
    UUIDが指定されてい無い場合は空文字が返ります。
    glueで接続文字を置き換えることができます。

  * ```uuid```

    スタックのUUIDを返します。
    UUIDが指定されてい無い場合は空文字が返ります。

  * ```properties(key)```

    オプション```--properties```で指定したキーに対応する値を参照することができます。


## Test

cfndkコマンドのテストを行うことができます。
CFNDK_COVERAGE環境変数に1を設定することで、カバレッジを取ることができます。

```
export AWS_REGION=ap-northeast-1
export AWS_PROFILE=default
export CFNDK_COVERAGE=1 
bundle exec rspec
```
