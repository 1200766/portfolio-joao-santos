import { Component, OnInit } from '@angular/core';
import { CommonModule } from '@angular/common';
import { FormsModule } from '@angular/forms';
import { UtentesService, Utente } from '../services/utentes.service';
import { RespostasService, Resposta } from '../services/respostas.service';
import { MedicosService, Medico } from '../services/medicos.service';
import { FilterUtentesPipe } from '../pipes/filter-utentes.pipe';
import { Router, RouterModule } from '@angular/router';
import { AuthService } from '../services/auth.service';

import { AdministradoresService, User } from '../services/administradores.service';
import { firstValueFrom } from 'rxjs';

@Component({
  selector: 'app-utentes-lista-med',
  standalone: true,
  imports: [
    CommonModule,
    FormsModule,
    FilterUtentesPipe,
    RouterModule
  ],
  templateUrl: './utentes-lista-med.component.html',
  styleUrls: ['./utentes-lista-med.component.css']
})
export class UtentesListaMedComponent implements OnInit {
  filtroNome: string = '';
  filtroNumero: string = '';
  utentes: Utente[] = [];
  medicos: Medico[] = [];

  user: User | null = null;

  usernameExistente: boolean = false;
  numeroExistente: boolean = false;

  submitted: boolean = false;
  showMenu: boolean = false;

  showModal: boolean = false;
  showInsertModal: boolean = false;
  showViewModal = false;
  utenteVisualizar: any = {};
  utenteQuestionario: any = {};
  utenteAssociadoVisualizar: any = {};
  showConsultaModal = false;
  consulta = {
    utenteId: '',
    data: '',
    hora: '',
    medico: ''
  };
  utentesAssociadoMedico: Utente[] = [];
  medicoId = ''
  medicoID = ''
  utenteSelecionado: Utente = this.criarUtenteVazio();
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

  constructor(
    private utentesService: UtentesService,
    private medicosService: MedicosService,
    private administradoresService: AdministradoresService,
    private respostasService: RespostasService,
    private authService: AuthService

  ) { }
verApenasAssociados: boolean = false;

ngOnInit(): void {
  this.utentesService.getUtentes().subscribe(data => {
    this.utentes = data;

    // Filtra os utentes associados ao médico depois de obter todos
    if (this.medicoID) {
      this.utentesAssociadoMedico = this.utentes.filter(
        utente => utente.medicoid === this.medicoID
      );
    }
  });

  this.user = this.authService.getUser();

  if (this.user) {
    this.authService.getUserAssociation(this.user._id).subscribe({
      next: (res) => {
        if (res && res.tipo === 'medico') {
          this.medicoID = res.id;

          // Refaz o filtro com base no ID do médico
          this.utentesAssociadoMedico = this.utentes.filter(
            utente => utente.medicoid === this.medicoID
          );
        }
      }
    });
  }
}


  respostasUtente: any[] = []; // guarda as respostas do utente
  toggleMenu() {
    console.log('toggleMenu clicado');
    this.showMenu = !this.showMenu;
  }
  logout() {
    this.authService.logout();
  }
  abrirViewModal(utente: any) {
    this.utenteVisualizar = { ...utente };
    this.showViewModal = true;

    const questionarioId = "6847039f629f3b4e324ff8bb";
    this.respostasUtente = [];

    this.respostasService.obterRespostas(utente.userId, questionarioId).subscribe({
      next: async (data) => {

        const respostaGrupo = data.respostas[0];
        const respostas = respostaGrupo.respostas;

        for (const resposta of respostas) {
          resposta.textoPergunta = '';
          resposta.textosResposta = [];

          try {
            const respostasTexto: string[] = [];

            // Para obter todas as respostas (caso haja mais de uma)
            const requests = resposta.idresposta.map((id: string) =>
              this.respostasService.obterQuestionario(questionarioId, resposta.perguntaId, id).toPromise()
            );

            const detalhes = await Promise.all(requests);

            // Extrai os textos da pergunta e das respostas
            if (detalhes.length > 0) {
              resposta.textoPergunta = detalhes[0].perguntaTexto;
              resposta.textosResposta = detalhes.map(d => d.respostaTexto);
            }

          } catch (err) {
            console.error('Erro ao buscar dados do questionário:');
          }
        }

        // Atualiza respostas para visualização
        this.respostasUtente = [{ respostas }];
      },
      error: (err) => {
        console.error('Erro ao obter respostas do utente:');
      }
    });
  }

  showAnamneseModal = false;
  respostasUtenteAnamenese: any[] = [];

  abrirAnamneseModal(utente: any) {
    this.utenteVisualizar = { ...utente };
    this.showAnamneseModal = true;
    this.respostasUtenteAnamenese = [];

    const anameneseId = "684711db1b25d03a14303ebd";

    this.respostasService.obterRespostas(utente.userId, anameneseId).subscribe({
      next: async (data) => {
        const respostaGrupo = data.respostas[0];
        const respostas = respostaGrupo.respostas;

        for (const resposta of respostas) {
          resposta.textoPergunta = '';
          resposta.textosResposta = [];

          try {
            const requests = resposta.idresposta.map((id: string) =>
              this.respostasService.obterQuestionario(anameneseId, resposta.perguntaId, id).toPromise()
            );

            const detalhes = await Promise.all(requests);

            if (detalhes.length > 0) {
              resposta.textoPergunta = detalhes[0].perguntaTexto;
              resposta.textosResposta = detalhes.map(d => d.respostaTexto);
            }

          } catch (err) {
            console.error('Erro ao buscar dados da anamnese:');
          }
        }

        this.respostasUtenteAnamenese = [{ respostas }];
      },
      error: (err) => {
        console.error('Erro ao obter respostas da anamnese:');
      }
    });
  }

  fecharAnamneseModal() {
    this.showAnamneseModal = false;
  }

  showAlertasModal: boolean = false;
  alertasUtenteSelecionado: any[] = [];

  abrirAlertasModal(utente: Utente) {
    this.alertasUtenteSelecionado = utente.alert || [];
    this.utenteVisualizar = utente;
    this.showAlertasModal = true;
  }

  fecharAlertasModal() {
    this.showAlertasModal = false;
  }

  getClasseAlerta(qtdAlertas: number): string {
    if (!qtdAlertas || qtdAlertas === 0) return 'text-success';  // verde
    if (qtdAlertas === 1 || qtdAlertas === 2) return 'text-warning';  // amarelo
    return 'text-danger';  // vermelho
  }



  fecharViewModal() {
    this.showViewModal = false;
  }


}
