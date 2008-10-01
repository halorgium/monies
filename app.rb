#!/usr/bin/env ruby

begin
  require 'rubygems'
rescue LoadError
  require 'minigems'
end

gem 'sinatra'
require 'sinatra'

gem 'ofx-parser'
require 'ofx-parser'

require 'thread'
require 'digest/sha1'
require 'yaml'

class OfxFile
  def self.files
    YAML.load_file(File.dirname(__FILE__) + "/files.yml")
  end

  def self.all
    files.map do |path|
      new(path)
    end
  end

  def self.at(sha1)
    all.find {|x| x.sha1 == sha1}
  end

  def initialize(path)
    @path = path
  end
  attr_reader :path

  def sha1
    Digest::SHA1.hexdigest(path)
  end

  def parser
    OfxParser::OfxParser.parse(open(path))
  end

  def accounts
    parser.accounts
  end

  def account_at(number)
    accounts.find {|x| x.number == number}
  end
end

module OfxParser
  class Account
    def transactions
      transactions_for
    end

    def transactions_for(type = nil, search = nil)
      types = {
        "credits" => :CREDIT,
        "debits" => :DEBIT,
      }
      TransactionSet.new(statement, types[type], search)
    end
  end

  class TransactionSet
    include Enumerable

    def initialize(statement, type, search)
      @statement, @type, @search = statement, type, search
    end

    def set
      @statement.transactions.select do |x|
        (!@type || x.type == @type) &&
          (!@search || x.memo =~ /#{@search}/)
      end
    end

    def total
      total = 0.0
      set.each do |t|
        total += t.amount.to_i
      end
      total
    end

    def each(&block)
      set.each(&block)
    end
  end

  class Transaction
    def color
      case type
      when :CREDIT
        "#33ccff"
      when :DEBIT
        "#ccffff"
      else
        "#ffffff"
      end
    end
  end
end

get '/' do
  @files = OfxFile.all
  haml :files
end

get '/:file' do
  @file = OfxFile.at(params[:file])
  @accounts = @file.accounts
  haml :accounts
end

get '/:file/:number' do
  @file = OfxFile.at(params[:file])
  @account = @file.account_at(params[:number])
  @transactions = @account.transactions_for(nil, params[:search])
  haml :account
end

get '/:file/:number.:type' do
  @file = OfxFile.at(params[:file])
  @account = @file.account_at(params[:number])
  @transactions = @account.transactions_for(params[:type], params[:search])
  haml :account
end
