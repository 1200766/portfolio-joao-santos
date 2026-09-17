import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { UtentesService, Utente } from '../services/utentes.service';
import { MedicosService, Medico } from '../services/medicos.service';
import { FilterUtentesPipe } from '../pipes/filter-utentes.pipe';
import { Router, RouterModule } from '@angular/router';

import { AdministradoresService, User } from '../services/administradores.service';
import { AuthService } from '../services/auth.service';
import { ConsultasService, Consulta } from '../services/consultas.service';


@Component({
  selector: 'app-utentes-lista',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    FilterUtentesPipe,
    RouterModule
  ],
  templateUrl: './utentes-lista.component.html',
  styleUrls: ['./utentes-lista.component.css', '../../styles.css']
})
export class UtentesListaComponent implements OnInit {
  filtroNome: string = '';
  filtroNumero: string = '';
  utentes: Utente[] = [];
  medicos: Medico[] = [];
  erroConsulta: string = '';

  showMenu: boolean = false;
  usernameExistente: boolean = false;
  numeroExistente: boolean = false;

  submitted: boolean = false;

  showModal: boolean = false;
  showInsertModal: boolean = false;
  showViewModal = false;
  utenteVisualizar: any = {};
  showConsultaModal = false;
  showViewConsultaModal = false;
  utenteParaConsultas: Utente | null = null;
  consulta = {
    utenteId: '',
    data: '',
    hora: '',
    medico: ''
  };

  user: User | null = null;

  utenteSelecionado: Utente = this.criarUtenteVazio();
  novoUtente: Utente = this.criarUtenteVazio();
  consultas: Consulta[] = [];

  constructor(
    private utentesService: UtentesService,
    private medicosService: MedicosService,
    private administradoresService: AdministradoresService,
    private authService: AuthService,
    private consultaService: ConsultasService

  ) { }

  ngOnInit(): void {
    this.utentesService.getUtentes().subscribe(data => {
      this.utentes = data;
    });

    this.medicosService.getMedicos().subscribe(data => {
      this.medicos = data;
    });
    this.user = this.authService.getUser();

  }
  toggleMenu() {
    console.log('toggleMenu clicado');
    this.showMenu = !this.showMenu;
  }
  abrirInsertModal(): void {
    this.novoUtente = this.criarUtenteVazio();
    this.numeroExistente = false;
    this.usernameExistente = false;
    this.submitted = false;
    this.showInsertModal = true;
  }

  fecharInsertModal(): void {
    this.showInsertModal = false;
  }

  abrirEditModal(utente: Utente): void {
    this.utenteSelecionado = { ...utente };
    this.showModal = true;
  }
  abrirCunsultaModal(utente: Utente): void {
    this.utenteSelecionado = { ...utente };
    this.showConsultaModal = true;
  }
  fecharConsultaModal(): void {
    this.showConsultaModal = false;
  }
  fecharEditModal(): void {
    this.showModal = false;
  }

  guardarNovoUtente(): void {
    this.submitted = true;

    const camposPreenchidos =
      this.novoUtente.nome.trim() !== '' &&
      this.novoUtente.contacto.trim() !== '' &&
      this.novoUtente.genero.trim() !== '' &&
      this.novoUtente.nascimento.trim() !== '' &&
      this.novoUtente.email.trim() !== '' &&
      this.novoUtente.username.trim() !== '' &&
      this.novoUtente.password.trim() !== '';

    const emailValido = this.isEmailValido();


    const passwordValida = this.isPasswordValida();
    const contactoValido = this.isContactoValido();
    const nascimentoValido = this.isDataNascimentoValida();

    this.numeroExistente = this.utentes.some(
      u => u.numeroUtente === this.novoUtente.numeroUtente
    );

    if (this.numeroExistente) {
      return; // Impede submissão se for duplicado
    }

    if (!camposPreenchidos || !emailValido || !passwordValida || !contactoValido ||
      !nascimentoValido || !this.novoUtente.medicoid || !this.isNumeroUtenteValido()) {
      return;
    }



    this.administradoresService.getUsers().subscribe(existing => {
      this.usernameExistente = existing.some(m => m.username === this.novoUtente.username);

      if (this.usernameExistente) {
        console.warn('Username já existe.');
        return;
      }

      // CONTINUAR O REGISTO
      const payload = {
        nome: this.novoUtente.nome,
        numeroUtenteSaude: this.novoUtente.numeroUtente,
        contacto: this.novoUtente.contacto,
        genero: this.novoUtente.genero,
        dataNascimento: new Date(this.novoUtente.nascimento).toISOString(),
        medico: this.novoUtente.medicoid,
        username: this.novoUtente.username,
        email: this.novoUtente.email,
        password: this.novoUtente.password,
        isAdmin: false
      };

      this.utentesService.registarUtente(payload).subscribe({
        next: () => {
          this.fecharInsertModal();
          this.utentesService.getUtentes().subscribe(data => this.utentes = data);
          alert('Novo utente inserido com sucesso!');
        },
        error: () => {
          alert('Erro ao inserir novo utente.');
        }
      });
    });
  }

  guardarEdicao(): void {
    this.submitted = true;

    const camposPreenchidos =
      this.utenteSelecionado.nome.trim() !== '' &&
      this.utenteSelecionado.contacto.trim() !== '' &&
      this.utenteSelecionado.genero.trim() !== '' &&
      this.utenteSelecionado.nascimento.trim() !== '';

    const contactoValido = /^\d{9}$/.test(this.utenteSelecionado.contacto);
    const nascimentoValido = new Date(this.utenteSelecionado.nascimento) < new Date();

    this.verificarNumeroEdicao()

    if (this.numeroExistente) {
      return; // Impede submissão se for duplicado
    }

    console.log('camposPreenchidos:', camposPreenchidos);
    console.log('contactoValido:', contactoValido);
    console.log('nascimentoValido:', nascimentoValido);

    if (!camposPreenchidos || !contactoValido || !nascimentoValido || !this.utenteSelecionado.medicoid || !this.isNumeroUtenteValidoEdit) {
      console.warn('Validação falhou. Não vai continuar.');
      return;
    }
    this.utentesService.atualizarUtente(this.utenteSelecionado).subscribe({
      next: () => {
        const index = this.utentes.findIndex(u => u.id === this.utenteSelecionado.id);
        if (index !== -1) {
          this.utentes[index] = { ...this.utenteSelecionado };
        }
        this.fecharEditModal();
        this.utentesService.getUtentes().subscribe(data => {
          this.utentes = data;
        });
        alert('Utente atualizado com sucesso!');
      },
      error: (err) => {
        console.error('Erro ao atualizar utente:');
        alert('Ocorreu um erro ao atualizar o utente.');
      }
    });
  }


  private criarUtenteVazio(): Utente {
    return {
      id: '',
      user: '',
      nome: '',
      numeroUtente: '',
      contacto: '',
      genero: '',
      nascimento: '',
      proximaConsulta: '',
      medico: '',
      medicoid: '',
      password: '',
      email: '',
      username: '',
      historicoId: '',
      userId: '',
      alert: ''
    };
  }
  delete(utente: Utente): void {
    if (confirm(`Tem certeza que deseja eliminar o utente ${utente.nome}?`)) {
      this.utentesService.deleteUtente(utente.username).subscribe({
        next: () => {
          this.utentes = this.utentes.filter(u => u.username !== utente.username);
          this.fecharEditModal();
          alert('Utente eliminado com sucesso!');
        },
        error: (err) => {
          console.error('Erro ao eliminar utente:');
          alert('Erro ao eliminar utente.');
        }
      });
    }

  }


  logout() {
    this.authService.logout();
  }
  abrirViewModal(utente: any) {
    this.utenteVisualizar = { ...utente };
    this.showViewModal = true;
  }

  fecharViewModal() {
    this.showViewModal = false;
  }

  guardarConsulta() {
    const dataCompleta = `${this.consulta.data}T${this.consulta.hora}:00`;
    const dataConsulta = new Date(dataCompleta);

    const agora = new Date();

    if (dataConsulta <= agora) {
      this.erroConsulta = "A data da consulta deve ser no futuro.";
      return;
    }
    const hora = dataConsulta.getHours();
    if (hora < 8 || hora >= 18) {
      this.erroConsulta = "Consultas só podem ser marcadas entre as 08h00 e as 18h00.";
      return;
    }

    this.consultaService.getConsultasDoMedico(this.consulta.medico).subscribe({
      next: (res) => {
        const consultas = res.resultado;

        const conflito = consultas.some(c => {
          const inicioExistente = this.parseLocalDateTime(c.data);
          const fimExistente = new Date(inicioExistente.getTime() + 30 * 60 * 1000);

          const inicioNova = dataConsulta;

          const fimNova = new Date(inicioNova.getTime() + 30 * 60 * 1000);

          // Verifica sobreposição
          return (
            (inicioNova < fimExistente && fimNova > inicioExistente)
          );
        });

        if (conflito) {
          this.erroConsulta = "Já existe uma consulta marcada para este horário para este médico.";
          return;
        }
        this.consultaService.getConsultasDoUtente(this.utenteSelecionado.id).subscribe({
          next: (consultasUtente) => {
            const conflitoUtente = consultasUtente.some(c => {
              const inicioExistente = this.converterData(c.data);
              const fimExistente = new Date(inicioExistente.getTime() + 30 * 60 * 1000);
              const inicioNova = dataConsulta;
              const fimNova = new Date(inicioNova.getTime() + 30 * 60 * 1000);
              return (inicioNova < fimExistente && fimNova > inicioExistente);
            });

            if (conflitoUtente) {
              this.erroConsulta = "O utente já tem uma consulta marcada neste horário.";
              return;
            }

            // 3. Nenhum conflito: Registar a consulta
            const consultaPayload = {
              utenteId: this.utenteSelecionado.id,
              data: dataCompleta,
              medico: this.consulta.medico
            };

            this.utentesService.registarConsulta(consultaPayload).subscribe({
              next: () => {
                alert('Consulta registada com sucesso!');
                this.utentesService.getUtentes().subscribe(data => this.utentes = data);
                this.fecharConsultaModal();
              },
              error: (err) => {
                console.error('Erro ao registar consulta:');
                alert('Erro ao registar consulta.');
              }
            });
          },
          error: (err) => {
            console.error('Erro ao verificar consultas do utente:');
            alert('Erro ao verificar conflitos do utente.');
          }
        });
      },
      error: (err) => {
        console.error('Erro ao verificar consultas do médico:');
        alert('Erro ao verificar conflitos do médico.');
      }
    });
  }

  converterData(dataStr: string): Date {
    // Exemplo: "16/06/2025 17:00 h"
    const [dataParte, horaParteRaw] = dataStr.split(' ');
    const [dia, mes, ano] = dataParte.split('/').map(Number);

    // Remove o "h" e espaços extras
    const horaParte = horaParteRaw.replace('h', '').trim();
    const [hora, minuto] = horaParte.split(':').map(Number);

    return new Date(ano, mes - 1, dia, hora, minuto);
  }


  parseLocalDateTime(str: string): Date {
    const [datePart, timePart] = str.split(' ');
    const [year, month, day] = datePart.split('-').map(Number);
    const [hour, minute] = timePart.split(':').map(Number);
    return new Date(year, month - 1, day, hour, minute);
  }

  isContactoValido(): boolean {
    return /^\d{9}$/.test(this.novoUtente.contacto);
  }

  isDataNascimentoValida(): boolean {
    const hoje = new Date();
    const nascimento = new Date(this.novoUtente.nascimento);
    return nascimento < hoje;
  }
  verificarUsername(): void {
    if (!this.novoUtente.username) {
      this.usernameExistente = false;
      return;
    }

    this.administradoresService.getUsers().subscribe(users => {
      this.usernameExistente = users.some(u => u.username === this.novoUtente.username);
    });
  }
  isEmailValido(): boolean {
    const regex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    return regex.test(this.novoUtente.email);
  }

  isPasswordValida(): boolean {
    return typeof this.novoUtente.password === 'string' && this.novoUtente.password.length >= 6;
  }

  isContactoValidoEdicao(): boolean {
    return /^\d{9}$/.test(this.utenteSelecionado.contacto);
  }

  isDataNascimentoValidaEdicao(): boolean {
    const hoje = new Date();
    const nascimento = new Date(this.utenteSelecionado.nascimento);
    return nascimento < hoje;
  }
  isNumeroUtenteValido(): boolean {
    return /^\d+$/.test(this.novoUtente.numeroUtente);
  }
  isNumeroUtenteValidoEdit(): boolean {
    return /^\d+$/.test(this.utenteSelecionado.numeroUtente);
  }



  verificarNumero(): void {
    this.numeroExistente = this.utentes.some(
      u => u.numeroUtente === this.novoUtente.numeroUtente
    );
  }

  verificarNumeroEdicao(): void {
    this.numeroExistente = this.utentes.some(
      u => u.numeroUtente === this.utenteSelecionado.numeroUtente &&
        u.username !== this.utenteSelecionado.username
    );
  }

  abrirModalEliminarConsulta(utente: Utente) {
    this.showViewConsultaModal = true;

    this.utenteParaConsultas = utente;
    this.consultas = [];

    this.consultaService.getConsultasDoUtente(utente.id).subscribe({
      next: (consultas) => {
        this.consultas = consultas;
        this.showViewConsultaModal = true;
      },
      error: (err) => {
        console.error('Erro ao carregar consultas:');
        alert('Erro ao obter consultas do utente.');
      }
    });
  }

  fecharModalConsultas() {
    this.showViewConsultaModal = false;
    this.consultas = [];
    this.utenteParaConsultas = null;
  }

  eliminarConsulta(consultaId: string) {
    if (!confirm('Tem certeza que deseja eliminar esta consulta?')) return;

    this.consultaService.eliminarConsulta(consultaId).subscribe({
      next: () => {
        this.consultas = this.consultas.filter(c => c.id !== consultaId);
        alert('Consulta eliminada com sucesso.');
        this.utentesService.getUtentes().subscribe(data => {
          this.utentes = data;
        });
        this.fecharConsultaModal();
      },
      error: (err) => {
        console.error('Erro ao eliminar consulta:');
        alert('Erro ao eliminar consulta.');
      }
    });
  }


}
