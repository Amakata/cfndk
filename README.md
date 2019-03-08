# AWS CloudFormation Development Kit

This is easy operation/integration support tool for AWS CloudFormation.

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

## インストール

```
$ gem install cfndk
```

## 使い方

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

## Credentials設定

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

## コマンド

```
cfndk [cmd] [options]
```

### [cmd]

#### ```init```

カレントディレクトリにcfndk.yamlのひな形を作成します。

```
cfndk init [option]
```

#### ```create```

cfndk.yamlで定義されているスタックを作成します。

```
cfndk create [option]
```

#### ```update```

cfndk.yamlで定義されているスタックを更新します。

```
cfndk update [option]
```

#### ```destroy```

cfndk.yamlで定義されているスタックを削除します。

```
cfndk destroy [option]
```

#### ```generate-uuid```

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

#### ```validate```

cfndk.yamlで定義されているスタックのテンプレートをvalidationします。

#### ```report```

cfndk.yamlで定義されているスタックについてレポートします。

```
cfndk report [option]
```

### [option]

#### ```-v --verbose```

実行時に詳細な情報を表示します。

#### ```-c, --config-path=cfndk.yml```

カレントディレクトリのcfndi.ymlの代わりに、ファイルを指定します。

#### ```-p, --properties=name:value```

プロパティを追加します。
cfndi.ymlのparametersのerb内で値で参照することができます。

####  ```-u, --uuid uuid```

指定されたUUIDを使用します。
UUIDが指定されるとスタック名に付加されます。
またcfndi.ymlのparametersの値で参照することができます。
```-u```は最後に指定されたものが有効になります。

#### ```--stack-names=name1 name2```

指定されたスタック名のみを操作します。

#### ```--keypair-names=name1 name2```

指定されたキーペア名のみを操作します。


#### ```--no-color```

メッセージ出力でカラーを抑制します。

### ```-f, --force```

動作の確認メッセージと入力をスキップします。

## 環境変数

### ```CFNDK_UUID```

この環境変数が指定されている場合、```--uuid $CFNDK_UUID```が指定されたものとして動作します。
```-u```のほうが優先されます。


## cfndk.yaml

* example

```
keypairs:
  Key1:
  Key2:
    key_file: key/key2<%= append_uuid %>.pem
stacks:
  Stack1:
    template_file: stack1/stack1.yaml 
    parameter_input: stack1/env.json
    parameters:
      VpcName: Prod<%= append_uuid %>
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
keypairs:
  [String]:
    key_file: [String]
stacks:
  [String]:
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
```

### ```keypairs:```

```
keypairs:
  [keypair Original Name]:
```

cfndkで管理するキーペアを定義します。
キーペアの配下には、管理するキーペアのオリジナル名を定義します。
通常は、キーペアを作成するとこの名称が利用されます。
UUIDを利用すると、```[Keypair Original Name]-[UUID]```のような形式のキーペア名が利用されます。

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

#### template_file 

必須。CloudFormationテンプレートファイルのパスをcfndk.yamlからの相対パスで指定します。

#### parameter_input

必須。CloudFormationのパラメータJSONファイルをcfndk.yamlからの相対パスで指定します。

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
dependsが循環するような指定をすることはできません。

```
    depends:
      - Stack1
      - Stack2  
```

#### timeout_in_minutes (デフォルト: 1)

スタックを作成する際などのタイムアウト時間を分で指定します。

```
    timeout_in_minutes: 5
```


### erbで使用できるメソッド

  * ```append_uuid(glue='-')```

    UUIDガ指定されている場合、```[glueの文字列] + [UUID]```を返します。
    UUIDが指定されてい無い場合は空文字が返ります。
    glueで接続文字を置き換えることができます。

  * ```uuid```

    UUIDを返します。
    UUIDが指定されてい無い場合は空文字が返ります。

  * ```properties(key)```

    オプション```--properties```で指定したキーに対応する値を参照することができます。


## テスト

cfndkコマンドのテストを行うことができます。
CFNDK_COVERAGE環境変数に1を設定することで、カバレッジを取ることができます。

```
export AWS_REGION=ap-northeast-1
export AWS_PROFILE=default
export CFNDK_COVERAGE=1 
bundle exec rspec
```
